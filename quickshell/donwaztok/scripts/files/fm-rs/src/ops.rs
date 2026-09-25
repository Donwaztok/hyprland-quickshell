//! File operations: mkdir, rename, delete, copy, move, undo-move, open, info.

use crate::entry::{mime_for, suffix_no_dot};
use crate::protocol::{err_exit, expand_user, out_ok, progress};
use crate::trash::{is_trash_uri, trash_original, trash_root};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use walkdir::WalkDir;

/// Spawn a GUI/executable detached from `fm` (and Quickshell's Process group).
/// Without setsid, AppImages die when the helper exits under qs Process.
fn spawn_detached(bin: &Path, cwd: &Path) -> Result<(), String> {
    let mut cmd = Command::new(bin);
    cmd.current_dir(cwd)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        // Force portal file dialogs → Donwaztok FileChooser (overrides gtk3/qt6ct).
        .env("GTK_USE_PORTAL", "1")
        .env("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");
    unsafe {
        cmd.pre_exec(|| {
            if libc::setsid() == -1 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    cmd.spawn().map_err(|e| e.to_string())?;
    Ok(())
}

pub fn do_mkdir(path: &str) {
    let p = expand_user(path);
    if let Err(e) = fs::create_dir(&p) {
        err_exit(&e.to_string());
    }
    out_ok(serde_json::json!({ "ok": true, "path": p.to_string_lossy() }));
}

pub fn do_mkfile(path: &str) {
    let p = expand_user(path);
    if p.exists() {
        err_exit(&format!("Already exists: {}", p.display()));
    }
    if let Some(parent) = p.parent() {
        if !parent.as_os_str().is_empty() && !parent.exists() {
            err_exit(&format!("Parent does not exist: {}", parent.display()));
        }
    }
    if let Err(e) = File::create(&p) {
        err_exit(&e.to_string());
    }
    out_ok(serde_json::json!({ "ok": true, "path": p.to_string_lossy() }));
}

pub fn do_rename(src: &str, dst: &str) {
    let s = expand_user(src);
    let d = expand_user(dst);
    if d.exists() {
        err_exit(&format!("Already exists: {}", d.display()));
    }
    if let Err(e) = fs::rename(&s, &d) {
        err_exit(&e.to_string());
    }
    out_ok(serde_json::json!({ "ok": true, "path": d.to_string_lossy() }));
}

pub fn do_delete(paths: &[String]) {
    let trash_files = trash_root().join("files");
    let trash_info = trash_root().join("info");
    for raw in paths {
        let p = expand_user(raw);
        if let Ok(parent) = p.parent().map(|x| x.to_path_buf()).ok_or(()) {
            if parent == trash_files
                || p.ancestors().any(|a| a == trash_files)
            {
                let info = trash_info.join(format!(
                    "{}.trashinfo",
                    p.file_name()
                        .map(|n| n.to_string_lossy())
                        .unwrap_or_default()
                ));
                let _ = fs::remove_file(info);
            }
        }
        if p.is_dir() && !p.is_symlink() {
            if let Err(e) = fs::remove_dir_all(&p) {
                err_exit(&e.to_string());
            }
        } else {
            let _ = fs::remove_file(&p);
        }
    }
    out_ok(serde_json::json!({ "ok": true, "count": paths.len() }));
}

fn path_size(path: &Path) -> u64 {
    if path.is_file() {
        return path.metadata().map(|m| m.len()).unwrap_or(0);
    }
    let mut total = 0u64;
    if path.is_dir() {
        for entry in WalkDir::new(path).follow_links(false).into_iter().flatten() {
            if entry.file_type().is_file() {
                total += entry.metadata().map(|m| m.len()).unwrap_or(0);
            }
        }
    }
    total
}

fn copy_file_with_progress(
    src: &Path,
    dst: &Path,
    copied: &mut u64,
    total: u64,
    label: &str,
) -> Result<(), String> {
    if let Some(parent) = dst.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let mut rf = File::open(src).map_err(|e| e.to_string())?;
    let mut wf = File::create(dst).map_err(|e| e.to_string())?;
    let mut buf = vec![0u8; 1024 * 1024];
    loop {
        let n = rf.read(&mut buf).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        wf.write_all(&buf[..n]).map_err(|e| e.to_string())?;
        *copied += n as u64;
        if total > 0 {
            progress((*copied as f64 / total as f64).min(0.99), label);
        }
    }
    let _ = fs::set_permissions(dst, src.metadata().map(|m| m.permissions()).unwrap_or_else(|_| {
        fs::Permissions::from_mode(0o644)
    }));
    Ok(())
}

fn copy_tree_with_progress(
    src: &Path,
    dst: &Path,
    copied: &mut u64,
    total: u64,
) -> Result<(), String> {
    fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    for entry in WalkDir::new(src).follow_links(false).into_iter().flatten() {
        let rel = entry.path().strip_prefix(src).unwrap_or(entry.path());
        let target = dst.join(rel);
        if entry.file_type().is_dir() {
            fs::create_dir_all(&target).map_err(|e| e.to_string())?;
        } else if entry.file_type().is_file() {
            let name = entry.file_name().to_string_lossy();
            copy_file_with_progress(
                entry.path(),
                &target,
                copied,
                total,
                &format!("Copying {name}"),
            )?;
        } else if entry.file_type().is_symlink() {
            if let Ok(link) = fs::read_link(entry.path()) {
                let _ = std::os::unix::fs::symlink(link, &target);
            }
        }
    }
    Ok(())
}

pub fn do_copy(sources: &[String], dest_dir: &str) {
    let dest = expand_user(dest_dir);
    if !dest.is_dir() {
        err_exit(&format!("Not a directory: {dest_dir}"));
    }
    let srcs: Vec<PathBuf> = sources.iter().map(|s| expand_user(s)).collect();
    let total = srcs.iter().map(|s| path_size(s)).sum::<u64>().max(1);
    let mut copied = 0u64;
    let mut results = Vec::new();
    progress(0.0, "Preparing copy…");
    for src in &srcs {
        let mut target = dest.join(src.file_name().unwrap_or_default());
        if target.exists() {
            let stem = src
                .file_stem()
                .map(|s| s.to_string_lossy().into_owned())
                .unwrap_or_default();
            let suffix = src
                .extension()
                .map(|e| format!(".{}", e.to_string_lossy()))
                .unwrap_or_default();
            let mut n = 1;
            while target.exists() {
                target = dest.join(format!("{stem} ({n}){suffix}"));
                n += 1;
            }
        }
        if src.is_dir() {
            if let Err(e) = copy_tree_with_progress(src, &target, &mut copied, total) {
                err_exit(&e);
            }
        } else if let Err(e) =
            copy_file_with_progress(src, &target, &mut copied, total, &format!("Copying {}", src.file_name().unwrap_or_default().to_string_lossy()))
        {
            err_exit(&e);
        }
        results.push(target.to_string_lossy().into_owned());
    }
    progress(1.0, "Done");
    out_ok(serde_json::json!({ "ok": true, "results": results }));
}

pub fn do_move(sources: &[String], dest_dir: &str) {
    let dest = expand_user(dest_dir);
    if !dest.is_dir() {
        err_exit(&format!("Not a directory: {dest_dir}"));
    }
    let mut results = Vec::new();
    let mut items = Vec::new();
    let n = sources.len().max(1) as f64;
    for (i, raw) in sources.iter().enumerate() {
        let src = expand_user(raw);
        let target = dest.join(src.file_name().unwrap_or_default());
        if target.exists() {
            err_exit(&format!("Already exists: {}", target.display()));
        }
        progress(i as f64 / n, &format!("Moving {}", src.file_name().unwrap_or_default().to_string_lossy()));
        let from = src.to_string_lossy().into_owned();
        if fs::rename(&src, &target).is_err() {
            // Cross-device fallback
            if src.is_dir() && !src.is_symlink() {
                if let Err(e) = copy_tree_with_progress(&src, &target, &mut 0, 1) {
                    err_exit(&e);
                }
                let _ = fs::remove_dir_all(&src);
            } else {
                if let Err(e) = fs::copy(&src, &target) {
                    err_exit(&e.to_string());
                }
                let _ = fs::remove_file(&src);
            }
        }
        let to = target.to_string_lossy().into_owned();
        results.push(to.clone());
        items.push(serde_json::json!({ "from": from, "to": to }));
    }
    progress(1.0, "Done");
    out_ok(serde_json::json!({
        "ok": true,
        "results": results,
        "items": items,
        "count": items.len(),
    }));
}

pub fn do_undo_move(pairs: &[String]) {
    if pairs.len() < 2 || pairs.len() % 2 != 0 {
        err_exit("undo-move expects to/from path pairs");
    }
    let mut restored = Vec::new();
    for i in (0..pairs.len()).step_by(2) {
        let src = expand_user(&pairs[i]);
        let dst = expand_user(&pairs[i + 1]);
        progress(
            i as f64 / pairs.len().max(1) as f64,
            &format!("Restoring {}", dst.file_name().unwrap_or_default().to_string_lossy()),
        );
        if !src.exists() {
            err_exit(&format!("Missing: {}", src.display()));
        }
        if dst.exists() {
            err_exit(&format!("Already exists: {}", dst.display()));
        }
        if let Some(parent) = dst.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if fs::rename(&src, &dst).is_err() {
            if src.is_dir() && !src.is_symlink() {
                if let Err(e) = copy_tree_with_progress(&src, &dst, &mut 0, 1) {
                    err_exit(&e);
                }
                let _ = fs::remove_dir_all(&src);
            } else {
                if let Err(e) = fs::copy(&src, &dst) {
                    err_exit(&e.to_string());
                }
                let _ = fs::remove_file(&src);
            }
        }
        restored.push(dst.to_string_lossy().into_owned());
    }
    progress(1.0, "Done");
    out_ok(serde_json::json!({
        "ok": true,
        "results": restored,
        "count": restored.len(),
    }));
}

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

#[allow(dead_code)]
pub fn do_open(path: &str) {
    match open_one(path) {
        Ok(v) => out_ok(v),
        Err(e) => err_exit(&e),
    }
}

pub fn do_open_many(paths: &[String]) {
    let mut opened = Vec::new();
    let mut errors = Vec::new();
    for path in paths {
        match open_one(path) {
            Ok(v) => opened.push(v),
            Err(e) => errors.push(serde_json::json!({ "path": path, "error": e })),
        }
    }
    if opened.is_empty() {
        let msg = errors
            .first()
            .and_then(|e| e.get("error"))
            .and_then(|e| e.as_str())
            .unwrap_or("Failed to open");
        err_exit(msg);
    }
    out_ok(serde_json::json!({
        "ok": true,
        "count": opened.len(),
        "opened": opened,
        "errors": errors,
    }));
}

fn open_one(path: &str) -> Result<serde_json::Value, String> {
    let mut p = expand_user(path);
    if let Ok(c) = p.canonicalize() {
        p = c;
    }
    if !p.exists() {
        return Err(format!("Not found: {path}"));
    }
    if p.is_dir() {
        return Err("Refusing to open a directory via open".into());
    }

    let name_l = p
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let executable = p.is_file()
        && p.metadata()
            .map(|m| m.permissions().mode() & 0o111 != 0)
            .unwrap_or(false);

    if name_l.ends_with(".appimage") {
        if !executable {
            if let Ok(meta) = p.metadata() {
                let mut perms = meta.permissions();
                perms.set_mode(perms.mode() | 0o111);
                if let Err(e) = fs::set_permissions(&p, perms) {
                    return Err(format!("AppImage is not executable: {e}"));
                }
            }
        }
        let cwd = p.parent().unwrap_or(Path::new("/"));
        spawn_detached(&p, cwd)?;
        return Ok(serde_json::json!({
            "ok": true,
            "mode": "exec",
            "path": p.to_string_lossy(),
        }));
    }

    let (code, msg) = run_cmd(&["gio", "open", &p.to_string_lossy()]);
    if code == 0 {
        return Ok(serde_json::json!({
            "ok": true,
            "mode": "gio",
            "path": p.to_string_lossy(),
        }));
    }

    let (code2, msg2) = run_cmd(&["xdg-open", &p.to_string_lossy()]);
    if code2 == 0 {
        return Ok(serde_json::json!({
            "ok": true,
            "mode": "xdg-open",
            "path": p.to_string_lossy(),
        }));
    }

    if executable {
        let cwd = p.parent().unwrap_or(Path::new("/"));
        spawn_detached(&p, cwd)?;
        return Ok(serde_json::json!({
            "ok": true,
            "mode": "exec-fallback",
            "path": p.to_string_lossy(),
        }));
    }

    let err_msg = if !msg.is_empty() {
        msg
    } else if !msg2.is_empty() {
        msg2
    } else {
        format!(
            "No application found for {}",
            p.file_name().map(|n| n.to_string_lossy()).unwrap_or_default()
        )
    };
    Err(err_msg)
}

fn user_name(uid: u32) -> String {
    unsafe {
        let pw = libc::getpwuid(uid);
        if pw.is_null() {
            return uid.to_string();
        }
        std::ffi::CStr::from_ptr((*pw).pw_name)
            .to_string_lossy()
            .into_owned()
    }
}

fn group_name(gid: u32) -> String {
    unsafe {
        let gr = libc::getgrgid(gid);
        if gr.is_null() {
            return gid.to_string();
        }
        std::ffi::CStr::from_ptr((*gr).gr_name)
            .to_string_lossy()
            .into_owned()
    }
}

fn filemode(mode: u32) -> String {
    let mut s = String::with_capacity(10);
    s.push(match mode & 0o170000 {
        0o040000 => 'd',
        0o120000 => 'l',
        0o010000 => 'p',
        0o140000 => 's',
        0o060000 => 'b',
        0o020000 => 'c',
        _ => '-',
    });
    let perms = [
        (0o400, 'r'),
        (0o200, 'w'),
        (0o100, 'x'),
        (0o040, 'r'),
        (0o020, 'w'),
        (0o010, 'x'),
        (0o004, 'r'),
        (0o002, 'w'),
        (0o001, 'x'),
    ];
    for (bit, ch) in perms {
        s.push(if mode & bit != 0 { ch } else { '-' });
    }
    // sticky/setuid/setgid bits simplified like Python filemode
    if mode & 0o4000 != 0 {
        let c = s.chars().nth(3).unwrap();
        s.replace_range(3..4, if c == 'x' { "s" } else { "S" });
    }
    if mode & 0o2000 != 0 {
        let c = s.chars().nth(6).unwrap();
        s.replace_range(6..7, if c == 'x' { "s" } else { "S" });
    }
    if mode & 0o1000 != 0 {
        let c = s.chars().nth(9).unwrap();
        s.replace_range(9..10, if c == 'x' { "t" } else { "T" });
    }
    s
}

fn walk_usage(path: &Path) -> (u64, usize, usize) {
    let mut file_count = 0usize;
    let mut dir_count = 0usize;
    let mut total = 0u64;
    fn walk(path: &Path, file_count: &mut usize, dir_count: &mut usize, total: &mut u64) {
        let Ok(rd) = fs::read_dir(path) else {
            return;
        };
        let mut dirs = Vec::new();
        let mut files = Vec::new();
        for ent in rd.flatten() {
            let p = ent.path();
            let ft = ent.file_type().ok();
            if ft.map(|t| t.is_dir() && !t.is_symlink()).unwrap_or(false) {
                dirs.push(p);
            } else {
                files.push(p);
            }
        }
        *dir_count += dirs.len();
        *file_count += files.len();
        for f in &files {
            if let Ok(m) = fs::symlink_metadata(f) {
                *total += m.len();
            }
        }
        for d in dirs {
            walk(&d, file_count, dir_count, total);
        }
    }
    walk(path, &mut file_count, &mut dir_count, &mut total);
    (total, file_count, dir_count)
}

fn path_info(raw: &str) -> Result<serde_json::Value, String> {
    if is_trash_uri(raw) {
        let mut usage = (0u64, 0usize, 0usize);
        let files_dir = trash_root().join("files");
        if files_dir.is_dir() {
            usage = walk_usage(&files_dir);
        }
        return Ok(serde_json::json!({
            "name": "Trash",
            "path": "trash://",
            "parent": "",
            "isDir": true,
            "isFile": false,
            "isSymlink": false,
            "linkTarget": "",
            "originalPath": "",
            "mimeType": "inode/directory",
            "suffix": "",
            "size": usage.0,
            "fileCount": usage.1,
            "dirCount": usage.2,
            "mtime": 0,
            "atime": 0,
            "ctime": 0,
            "mode": "",
            "modeOctal": "",
            "owner": "",
            "group": "",
            "exists": true,
        }));
    }

    let p = expand_user(raw);
    let st = fs::symlink_metadata(&p).map_err(|e| e.to_string())?;
    let is_link = st.file_type().is_symlink();
    let is_dir = if is_link {
        fs::canonicalize(&p).map(|c| c.is_dir()).unwrap_or(false)
    } else {
        st.is_dir()
    };

    let target = if is_link {
        fs::read_link(&p)
            .map(|t| t.to_string_lossy().into_owned())
            .unwrap_or_default()
    } else {
        String::new()
    };

    let (size, file_count, dir_count) = if is_dir {
        let u = walk_usage(&p);
        (u.0, u.1, u.2)
    } else {
        (st.len(), 1, 0)
    };

    let mode = st.mode();
    Ok(serde_json::json!({
        "name": p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| p.to_string_lossy().into_owned()),
        "path": p.to_string_lossy(),
        "parent": p.parent().map(|x| x.to_string_lossy().into_owned()).unwrap_or_default(),
        "isDir": is_dir,
        "isFile": !is_dir && p.is_file(),
        "isSymlink": is_link,
        "linkTarget": target,
        "originalPath": trash_original(&p),
        "mimeType": mime_for(&p, is_dir),
        "suffix": suffix_no_dot(&p),
        "size": size,
        "fileCount": file_count,
        "dirCount": dir_count,
        "mtime": st.mtime(),
        "atime": st.atime(),
        "ctime": st.ctime(),
        "mode": filemode(mode),
        "modeOctal": format!("{:03o}", mode & 0o777),
        "owner": user_name(st.uid()),
        "group": group_name(st.gid()),
        "exists": true,
    }))
}

pub fn do_info(paths: &[String]) {
    let mut items = Vec::new();
    for raw in paths {
        match path_info(raw) {
            Ok(v) => items.push(v),
            Err(e) => {
                let name = Path::new(raw)
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_else(|| raw.clone());
                items.push(serde_json::json!({
                    "name": name,
                    "path": raw,
                    "parent": Path::new(raw).parent().map(|p| p.to_string_lossy()).unwrap_or_default(),
                    "isDir": false,
                    "isFile": false,
                    "isSymlink": false,
                    "linkTarget": "",
                    "originalPath": "",
                    "mimeType": "",
                    "suffix": "",
                    "size": 0,
                    "fileCount": 0,
                    "dirCount": 0,
                    "mtime": 0,
                    "atime": 0,
                    "ctime": 0,
                    "mode": "",
                    "modeOctal": "",
                    "owner": "",
                    "group": "",
                    "exists": false,
                    "error": e,
                }));
            }
        }
    }

    let total_size: u64 = items
        .iter()
        .map(|i| i.get("size").and_then(|v| v.as_u64()).unwrap_or(0))
        .sum();
    let selected_files = items
        .iter()
        .filter(|i| !i.get("isDir").and_then(|v| v.as_bool()).unwrap_or(false))
        .count();
    let selected_dirs = items
        .iter()
        .filter(|i| i.get("isDir").and_then(|v| v.as_bool()).unwrap_or(false))
        .count();
    let child_files: usize = items
        .iter()
        .map(|i| i.get("fileCount").and_then(|v| v.as_u64()).unwrap_or(0) as usize)
        .sum();
    let child_dirs: usize = items
        .iter()
        .map(|i| i.get("dirCount").and_then(|v| v.as_u64()).unwrap_or(0) as usize)
        .sum();

    out_ok(serde_json::json!({
        "ok": true,
        "count": items.len(),
        "items": items,
        "totalSize": total_size,
        "selectedFiles": selected_files,
        "selectedDirs": selected_dirs,
        "childFiles": child_files,
        "childDirs": child_dirs,
    }));
}

