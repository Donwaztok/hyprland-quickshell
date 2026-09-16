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
