//! inotify directory watch — emits ready then change events for QML.

use crate::protocol::{emit, err_exit};
use crate::trash::{is_trash_uri, trash_root};
use nix::sys::inotify::{AddWatchFlags, InitFlags, Inotify};
use std::path::Path;

pub fn watch_dir(path: &str) {
    let watch_path = if is_trash_uri(path) {
        let target = trash_root().join("files");
        let _ = std::fs::create_dir_all(&target);
        target
    } else {
        let p = crate::protocol::expand_user(path);
        if !p.is_dir() {
            err_exit(&format!("Not a directory: {path}"));
        }
        p
    };

    let watch_str = watch_path.to_string_lossy().into_owned();

    let inotify = match Inotify::init(InitFlags::IN_CLOEXEC) {
        Ok(i) => i,
        Err(_) => err_exit("inotify init failed"),
    };

    let flags = AddWatchFlags::IN_ATTRIB
        | AddWatchFlags::IN_CLOSE_WRITE
        | AddWatchFlags::IN_MOVED_FROM
        | AddWatchFlags::IN_MOVED_TO
        | AddWatchFlags::IN_CREATE
        | AddWatchFlags::IN_DELETE
        | AddWatchFlags::IN_DELETE_SELF
        | AddWatchFlags::IN_MOVE_SELF
        | AddWatchFlags::IN_ONLYDIR;

    if inotify.add_watch(Path::new(&watch_str), flags).is_err() {
        err_exit(&format!("inotify watch failed: {watch_str}"));
    }

    emit(&serde_json::json!({
        "type": "ready",
        "ok": true,
        "path": watch_str,
    }));

    loop {
        match inotify.read_events() {
            Ok(events) => {
                if !events.is_empty() {
                    emit(&serde_json::json!({
                        "type": "change",
                        "ok": true,
                    }));
                }
            }
            Err(nix::errno::Errno::EINTR) => continue,
            Err(_) => break,
        }
    }
}

/// Prints one line per change to the mount table or to the block devices (plug, unplug, unlock).
/// Replaces `udisksctl monitor`, which kept udisksd running from boot just to watch; now udisksd
/// starts on D-Bus demand when something is mounted or ejected.
pub fn watch_mounts() {
    use std::fs::File;
    use std::io::{Read, Seek};
    use std::os::fd::AsRawFd;

    let mut mounts = File::open("/proc/self/mountinfo").unwrap_or_else(|e| err_exit(&format!("mountinfo: {e}")));
    let mut drain = Vec::new();
    let _ = mounts.read_to_end(&mut drain); // the kernel flags changes made after the first read

    // udev's multicast group (2): events arrive after the rules ran, so lsblk already sees labels.
    let sock = unsafe { libc::socket(libc::AF_NETLINK, libc::SOCK_DGRAM | libc::SOCK_CLOEXEC, libc::NETLINK_KOBJECT_UEVENT) };
    let mut addr: libc::sockaddr_nl = unsafe { std::mem::zeroed() };
    addr.nl_family = libc::AF_NETLINK as u16;
    addr.nl_groups = 2;
    let bound = sock >= 0
        && unsafe { libc::bind(sock, &addr as *const _ as *const libc::sockaddr, std::mem::size_of_val(&addr) as u32) } == 0;
    if !bound {
        eprintln!("fm watch-mounts: no udev events ({}); only mount changes are reported", std::io::Error::last_os_error());
    }

    emit(&serde_json::json!({"type": "ready"}));
    let mut buf = vec![0u8; 16384];
    loop {
        let mut fds = [
            libc::pollfd { fd: mounts.as_raw_fd(), events: libc::POLLPRI, revents: 0 },
            libc::pollfd { fd: if bound { sock } else { -1 }, events: libc::POLLIN, revents: 0 },
        ];
        if unsafe { libc::poll(fds.as_mut_ptr(), 2, -1) } < 0 {
            continue; // EINTR
        }
        if fds[0].revents != 0 {
            drain.clear();
            let _ = mounts.rewind().and_then(|_| mounts.read_to_end(&mut drain));
            emit(&serde_json::json!({"type": "mounts"}));
        }
        if fds[1].revents & libc::POLLIN != 0 {
            let n = unsafe { libc::recv(sock, buf.as_mut_ptr().cast(), buf.len(), 0) };
            if n > 0 && is_block_event(&buf[..n as usize]) {
                emit(&serde_json::json!({"type": "block"}));
            }
        }
    }
}

/// udev messages carry NUL-separated KEY=VALUE pairs after a binary header.
fn is_block_event(msg: &[u8]) -> bool {
    msg.split(|b| *b == 0).any(|kv| kv == b"SUBSYSTEM=block")
}

#[cfg(test)]
mod tests {
    #[test]
    fn block_events_only() {
        assert!(super::is_block_event(b"libudev\0\xfe\xed\0ACTION=add\0SUBSYSTEM=block\0DEVNAME=/dev/sdb\0"));
        assert!(!super::is_block_event(b"libudev\0ACTION=add\0SUBSYSTEM=usb\0"));
        assert!(!super::is_block_event(b"ACTION=add\0SUBSYSTEM=blocker\0"));
    }
}
