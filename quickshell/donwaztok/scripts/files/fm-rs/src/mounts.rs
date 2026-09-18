//! Mounts listing and eject/mount via udisksctl/gio/umount.

use crate::entry::dirs_home;
use crate::protocol::{err_exit, expand_user, out_ok};
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;

const REAL_FS: &[&str] = &[
    "ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "ntfs", "ntfs3", "vfat", "exfat", "fuseblk",
    "fuse.ntfs", "fuse.exfat", "zfs",
];

fn run_cmd(cmd: &[&str]) -> (i32, String) {
    match Command::new(cmd[0]).args(&cmd[1..]).output() {
        Ok(out) => {
            let code = out.status.code().unwrap_or(1);
            let msg = String::from_utf8_lossy(&out.stderr);
            let msg = if msg.trim().is_empty() {
                String::from_utf8_lossy(&out.stdout).trim().to_string()
            } else {
                msg.trim().to_string()
            };
            (code, msg)
        }
        Err(e) => (127, e.to_string()),
    }
}

fn is_useful_mount(point: &str) -> bool {
    if point.is_empty() || !point.starts_with('/') {
        return false;
    }
    if !Path::new(point).is_dir() {
        return false;
    }
    let skip_prefixes = [
        "/snap",
        "/boot",
        "/var/lib/docker",
        "/var/lib/containers",
        "/run/credentials",
        "/run/user",
        "/sys",
        "/proc",
        "/dev",
        "/etc",
        "/usr",
        "/root",
        "/srv",
        "/var/cache",
        "/var/log",
        "/var/tmp",
        "/nix",
    ];
    for s in skip_prefixes {
        if point == s || point.starts_with(&format!("{s}/")) {
            return false;
        }
    }
    let home = dirs_home().to_string_lossy().into_owned();
    if point.starts_with(&format!("{home}/"))
        && point.matches('/').count() >= home.matches('/').count() + 2
    {
        return false;
    }
    true
}

pub fn list_mounts() {
    let output = Command::new("lsblk")
        .args([
            "-J",
            "-b",
            "-o",
            "NAME,LABEL,SIZE,FSUSED,FSSIZE,FSAVAIL,MOUNTPOINTS,TYPE,HOTPLUG,RM,TRAN,FSTYPE,PATH",
        ])
        .output();
    let raw = match output {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).into_owned(),
        Ok(o) => err_exit(&format!(
            "lsblk failed: {}",
            String::from_utf8_lossy(&o.stderr)
        )),
        Err(e) => err_exit(&format!("lsblk failed: {e}")),
    };
    let data: Value = match serde_json::from_str(&raw) {
        Ok(v) => v,
        Err(e) => err_exit(&format!("lsblk failed: {e}")),
    };

    let mut mounts = Vec::new();
    let mut seen_mounts = std::collections::HashSet::new();
    let mut seen_devices = std::collections::HashSet::new();
    let home = dirs_home().to_string_lossy().into_owned();

    fn is_removable(rm: bool, hot: bool, tran: &str, point: &str) -> bool {
        rm || hot
            || matches!(tran, "usb" | "mmc")
            || (!point.is_empty()
                && (point.starts_with("/run/media") || point.starts_with("/media")))
    }

    fn walk(
        dev: &Value,
        parent_rm: bool,
        parent_hot: bool,
        parent_tran: &str,
        mounts: &mut Vec<Value>,
        seen_mounts: &mut std::collections::HashSet<String>,
        seen_devices: &mut std::collections::HashSet<String>,
        home: &str,
    ) {
        let rm = dev.get("rm").and_then(|v| v.as_bool()).unwrap_or(false) || parent_rm;
        let hot = dev
            .get("hotplug")
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
            || parent_hot;
        let tran = dev
            .get("tran")
            .and_then(|v| v.as_str())
            .unwrap_or(parent_tran)
            .to_lowercase();
        let fstype = dev
            .get("fstype")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        let dtype = dev
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();

        let mut points = Vec::new();
        if let Some(mp) = dev.get("mountpoints").or_else(|| dev.get("mountpoint")) {
            if let Some(arr) = mp.as_array() {
                for p in arr {
                    if let Some(s) = p.as_str() {
                        if !s.is_empty() && s != "[SWAP]" {
                            points.push(s.to_string());
                        }
                    }
                }
            } else if let Some(s) = mp.as_str() {
                if !s.is_empty() && s != "[SWAP]" {
                    points.push(s.to_string());
                }
            }
        }

        let device_name = dev
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let device_path = {
            let p = dev
                .get("path")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .trim()
                .to_string();
            if p.is_empty() && !device_name.is_empty() {
                format!("/dev/{device_name}")
            } else {
                p
            }
        };
        let label = dev
            .get("label")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim()
            .to_string();
        let removable = is_removable(rm, hot, &tran, "");

        for point in &points {
            if seen_mounts.contains(point) {
                continue;
            }
            if !is_useful_mount(point) {
                continue;
            }
            if !fstype.is_empty()
                && !REAL_FS.contains(&fstype.as_str())
                && !fstype.starts_with("fuse")
                && point != "/"
                && point != "/home"
                && !point.starts_with("/run/media")
                && !point.starts_with("/media")
                && !point.starts_with("/mnt")
            {
                continue;
            }
            let fssize = dev.get("fssize").and_then(|v| v.as_u64()).unwrap_or(0);
            let fsused = dev.get("fsused").and_then(|v| v.as_u64()).unwrap_or(0);
            let fsavail = dev.get("fsavail").and_then(|v| v.as_u64()).unwrap_or(0);
            if fssize == 0 {
                continue;
            }
            seen_mounts.insert(point.clone());
            if !device_path.is_empty() {
                seen_devices.insert(device_path.clone());
            }
            let mut name = if !label.is_empty() {
                label.clone()
            } else {
                Path::new(point)
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .filter(|s| !s.is_empty())
                    .unwrap_or_else(|| {
                        if device_name.is_empty() {
                            point.clone()
                        } else {
                            device_name.clone()
                        }
                    })
            };
            if point == "/" {
                name = "System".into();
            } else if point == home || point == "/home" {
                name = "Home".into();
            }
            let rem = is_removable(rm, hot, &tran, point);
            mounts.push(serde_json::json!({
                "name": name,
                "device": device_name,
                "devicePath": device_path,
                "mount": point,
                "label": label,
                "fstype": fstype,
                "total": fssize,
                "used": fsused,
                "free": if fsavail > 0 { fsavail } else { fssize.saturating_sub(fsused) },
                "perc": if fssize > 0 { fsused as f64 / fssize as f64 } else { 0.0 },
                "removable": rem,
                "mounted": true,
                "ejectable": rem && point != "/" && point != "/home" && point != home,
                "tran": tran,
            }));
        }

        if points.is_empty() && removable && !device_path.is_empty() && !seen_devices.contains(&device_path)
        {
            if (dtype == "part" || dtype == "crypt")
                || (dtype == "disk" && !fstype.is_empty())
            {
                if !fstype.is_empty()
                    && (REAL_FS.contains(&fstype.as_str()) || fstype.starts_with("fuse"))
                {
                    let size = dev.get("size").and_then(|v| v.as_u64()).unwrap_or(0);
                    let name = if !label.is_empty() {
                        label.clone()
                    } else if !device_name.is_empty() {
                        device_name.clone()
                    } else {
                        device_path.clone()
                    };
                    seen_devices.insert(device_path.clone());
                    mounts.push(serde_json::json!({
                        "name": name,
                        "device": device_name,
                        "devicePath": device_path,
                        "mount": "",
                        "label": label,
                        "fstype": fstype,
                        "total": size,
                        "used": 0,
                        "free": size,
                        "perc": 0,
                        "removable": true,
                        "mounted": false,
                        "ejectable": false,
                        "tran": tran,
                    }));
                }
            }
        }

        if let Some(children) = dev.get("children").and_then(|v| v.as_array()) {
            for child in children {
                walk(
                    child,
                    rm,
                    hot,
                    &tran,
                    mounts,
                    seen_mounts,
                    seen_devices,
                    home,
                );
            }
        }
    }

    if let Some(blocks) = data.get("blockdevices").and_then(|v| v.as_array()) {
        for block in blocks {
            walk(
                block,
                false,
                false,
                "",
                &mut mounts,
                &mut seen_mounts,
                &mut seen_devices,
                &home,
            );
        }
    }

    mounts.sort_by(|a, b| {
        let am = a.get("mount").and_then(|v| v.as_str()).unwrap_or("");
        let bm = b.get("mount").and_then(|v| v.as_str()).unwrap_or("");
        let key = |m: &str, rem: bool, mounted: bool, name: &str| {
            (
                if m == "/" { 0 } else { 1 },
                if !rem { 0 } else { 1 },
                if mounted { 0 } else { 1 },
                name.to_lowercase(),
            )
        };
        key(
            am,
            a.get("removable").and_then(|v| v.as_bool()).unwrap_or(false),
            a.get("mounted").and_then(|v| v.as_bool()).unwrap_or(false),
            a.get("name").and_then(|v| v.as_str()).unwrap_or(""),
        )
        .cmp(&key(
            bm,
            b.get("removable").and_then(|v| v.as_bool()).unwrap_or(false),
            b.get("mounted").and_then(|v| v.as_bool()).unwrap_or(false),
            b.get("name").and_then(|v| v.as_str()).unwrap_or(""),
        ))
    });

    out_ok(serde_json::json!({ "ok": true, "mounts": mounts }));
}

fn block_source_for_mount(mount_point: &str) -> String {
    let out = Command::new("findmnt")
        .args(["-n", "-o", "SOURCE", "--target", mount_point])
        .output();
    match out {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
            s.split('[').next().unwrap_or(&s).trim().to_string()
        }
        _ => String::new(),
    }
}

fn disk_for_partition(device: &str) -> String {
    if device.is_empty() {
        return String::new();
    }
    if let Ok(o) = Command::new("lsblk").args(["-no", "PKNAME", device]).output() {
        if o.status.success() {
            let parent = String::from_utf8_lossy(&o.stdout)
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .to_string();
            if !parent.is_empty() {
                return format!("/dev/{parent}");
            }
        }
    }
    if let Ok(o) = Command::new("lsblk").args(["-no", "TYPE", device]).output() {
        if o.status.success() {
            let dtype = String::from_utf8_lossy(&o.stdout)
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .to_string();
            if dtype == "disk" || dtype == "rom" {
                return device.to_string();
            }
        }
    }
    device.to_string()
}

fn mount_targets_for_device(device: &str) -> Vec<String> {
    let out = Command::new("findmnt")
        .args(["-n", "-o", "TARGET", "-S", device])
        .output();
    match out {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout)
            .lines()
            .map(|l| l.trim().to_string())
            .filter(|l| !l.is_empty())
            .collect(),
        _ => Vec::new(),
    }
}

fn is_mount_live(mount_point: &str) -> bool {
    Command::new("findmnt")
        .args(["-n", "--target", mount_point])
        .output()
        .map(|o| o.status.success() && !String::from_utf8_lossy(&o.stdout).trim().is_empty())
        .unwrap_or(false)
}

fn busy_hint(mount_point: &str) -> String {
    for cmd in [
        vec!["fuser", "-vm", mount_point],
        vec!["lsof", "+f", "--", mount_point],
    ] {
        let (code, msg) = run_cmd(&cmd);
        let _ = code;
        if !msg.is_empty() {
            let lines: Vec<_> = msg
                .lines()
                .map(|l| l.trim())
                .filter(|l| !l.is_empty())
                .take(6)
                .collect();
            if !lines.is_empty() {
                return format!("In use by: {}", lines.iter().take(4).cloned().collect::<Vec<_>>().join("; "));
            }
        }
    }
    "Close apps/terminals using this drive, then try again.".into()
}

fn device_node_exists(device: &str) -> bool {
    !device.is_empty() && Path::new(device).exists()
}

pub fn do_eject(mount_point: &str) {
    let mp = expand_user(mount_point).to_string_lossy().into_owned();
    let home = dirs_home().to_string_lossy().into_owned();
    if mp == "/" || mp == "/home" || mp == home {
        err_exit("Refusing to eject system volume");
    }

    thread::sleep(Duration::from_millis(500));

    let uri = format!("file://{mp}");
    let source = if is_mount_live(&mp) {
        block_source_for_mount(&mp)
    } else {
        String::new()
    };
    let disk = if !source.is_empty() {
        disk_for_partition(&source)
    } else {
        String::new()
    };

    if !is_mount_live(&mp) {
        if !disk.is_empty() && device_node_exists(&disk) {
            let (code, _) = run_cmd(&[
                "udisksctl",
                "power-off",
                "-b",
                &disk,
                "--no-user-interaction",
            ]);
            out_ok(serde_json::json!({
                "ok": true,
                "mount": mp,
                "device": source,
                "disk": disk,
                "poweredOff": code == 0 || !device_node_exists(&disk),
                "mode": "eject",
            }));
            return;
        }
        out_ok(serde_json::json!({
            "ok": true,
            "mount": mp,
            "mode": "eject",
            "alreadyUnmounted": true,
            "poweredOff": true,
        }));
        return;
    }

    let (code, _) = run_cmd(&["gio", "mount", "-e", &uri]);
    if code != 0 && is_mount_live(&mp) {
        thread::sleep(Duration::from_millis(400));
        let _ = run_cmd(&["gio", "mount", "-e", "-f", &uri]);
    }

    if is_mount_live(&mp) {
        let (_, msg) = run_cmd(&["gio", "mount", "-u", "-f", &uri]);
        if is_mount_live(&mp) {
            err_exit(&format!(
                "{}\n{}",
                if msg.is_empty() {
                    "Device is busy".into()
                } else {
                    msg
                },
                busy_hint(&mp)
            ));
        }
        if !disk.is_empty() && device_node_exists(&disk) {
            thread::sleep(Duration::from_millis(250));
            let _ = run_cmd(&[
                "udisksctl",
                "power-off",
                "-b",
                &disk,
                "--no-user-interaction",
            ]);
        }
    }

    let powered_off = disk.is_empty() || !device_node_exists(&disk);
    out_ok(serde_json::json!({
        "ok": true,
        "mount": mp,
        "device": source,
        "disk": disk,
        "poweredOff": powered_off,
        "mode": "eject",
    }));
}

pub fn do_mount(device: &str) {
    let dev = device.trim().to_string();
    if dev.is_empty() {
        err_exit("No device");
    }
    let existing = mount_targets_for_device(&dev);
    if let Some(first) = existing.first() {
        out_ok(serde_json::json!({
            "ok": true,
            "mount": first,
            "device": dev,
            "alreadyMounted": true,
        }));
        return;
    }

    let (code, msg) = run_cmd(&["gio", "mount", "-d", &dev]);
    if code != 0 {
        err_exit(&if msg.is_empty() {
            format!("Failed to mount {dev}")
        } else {
            msg
        });
    }

    let mut targets = mount_targets_for_device(&dev);
    if targets.is_empty() {
        thread::sleep(Duration::from_millis(300));
        targets = mount_targets_for_device(&dev);
    }
    if targets.is_empty() {
        err_exit(&if msg.is_empty() {
            format!("Mounted but mountpoint not found for {dev}")
        } else {
            msg
        });
    }

    out_ok(serde_json::json!({
        "ok": true,
        "mount": targets[0],
        "device": dev,
    }));
}

pub fn xdg_dirs() {
    let home = dirs_home();
    let specs: Vec<(&str, Option<&str>, &str, &[&str])> = vec![
        ("home", None, "home", &[]),
        (
            "downloads",
            Some("DOWNLOAD"),
            "download",
            &["Downloads", "Download", "Baixados", "Transferências", "Transferencias"],
        ),
        (
            "desktop",
            Some("DESKTOP"),
            "desktop_windows",
            &[
                "Desktop",
                "Área de trabalho",
                "Area de trabalho",
                "Área de Trabalho",
                "Escritorio",
                "Escritório",
            ],
        ),
        (
            "documents",
            Some("DOCUMENTS"),
            "description",
            &["Documents", "Documentos", "Docs"],
        ),
        (
            "music",
            Some("MUSIC"),
            "music_note",
            &["Music", "Músicas", "Musicas", "Música", "Musica"],
        ),
        (
            "pictures",
            Some("PICTURES"),
            "image",
            &["Pictures", "Imagens", "Images", "Fotos", "Photos"],
        ),
        (
            "videos",
            Some("VIDEOS"),
            "movie",
            &["Videos", "Vídeos", "Video", "Vídeo", "Movies", "Filmes"],
        ),
    ];

    let mut result = serde_json::json!({ "ok": true, "home": home.to_string_lossy() });
    let mut places = Vec::new();

    fn add_unique(paths: &mut Vec<PathBuf>, path: PathBuf, home: &Path) {
        if !path.is_dir() {
            return;
        }
        let Ok(resolved) = path.canonicalize() else {
            return;
        };
        // XDG dirs disabled with "$HOME/" must not appear as extra Places.
        if let Ok(home_resolved) = home.canonicalize() {
            if resolved == home_resolved {
                return;
            }
        }
        for existing in paths.iter() {
            if let Ok(e) = existing.canonicalize() {
                if e == resolved {
                    return;
                }
            }
        }
        paths.push(path);
    }

    for (key, xdg, icon, names) in specs {
        let mut found: Vec<PathBuf> = Vec::new();
        if key == "home" {
            found = vec![home.clone()];
            result["home"] = serde_json::json!(home.to_string_lossy());
            result["homeExists"] = serde_json::json!(true);
        } else {
            if let Some(xdg_name) = xdg {
                if let Ok(o) = Command::new("xdg-user-dir").arg(xdg_name).output() {
                    if o.status.success() {
                        let p = String::from_utf8_lossy(&o.stdout).trim().to_string();
                        if !p.is_empty() {
                            add_unique(&mut found, PathBuf::from(p), &home);
                        }
                    }
                }
            }
            for name in names {
                add_unique(&mut found, home.join(name), &home);
            }
            if !names.is_empty() {
                found.sort_by_key(|p| {
                    names
                        .iter()
                        .position(|n| p.file_name().and_then(|f| f.to_str()) == Some(*n))
                        .unwrap_or(names.len() + 1)
                });
            }
            let preferred = found
                .first()
                .cloned()
                .unwrap_or_else(|| home.join(names.first().copied().unwrap_or(key)));
            result[key] = serde_json::json!(preferred.to_string_lossy());
            result[format!("{key}Exists")] = serde_json::json!(!found.is_empty());
        }

        for path in &found {
            let label = if key == "home" {
                "Home".into()
            } else {
                path.file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_else(|| path.to_string_lossy().into_owned())
            };
            places.push(serde_json::json!({
                "key": key,
                "label": label,
                "path": path.to_string_lossy(),
                "icon": icon,
            }));
        }
    }

    places.push(serde_json::json!({
        "key": "trash",
        "label": "Trash",
        "path": "trash://",
        "icon": "delete",
    }));
    result["trash"] = serde_json::json!("trash://");
    result["places"] = serde_json::json!(places);
    out_ok(result);
}
