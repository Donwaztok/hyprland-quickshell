//! XDG trash operations (without requiring gio).

use crate::list::build_trash_list_entry;
use crate::protocol::{err_exit, expand_user, out_ok};
use chrono::Local;
use percent_encoding::{utf8_percent_encode, AsciiSet, CONTROLS};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Encode path for trashinfo Path= (encode most non-unreserved except /).
const PATH_ENCODE: &AsciiSet = &CONTROLS
    .add(b' ')
    .add(b'"')
    .add(b'#')
    .add(b'%')
    .add(b'<')
    .add(b'>')
    .add(b'?')
    .add(b'[')
    .add(b'\\')
    .add(b']')
    .add(b'^')
    .add(b'`')
    .add(b'{')
    .add(b'|')
    .add(b'}');

pub fn trash_root() -> PathBuf {
    let data = std::env::var("XDG_DATA_HOME")
        .unwrap_or_else(|_| format!("{}/.local/share", crate::entry::dirs_home().display()));
    PathBuf::from(data).join("Trash")
}

pub fn is_trash_uri(path: &str) -> bool {
    matches!(path, "trash://" | "trash:/" | "trash:") || path.starts_with("trash://")
}

pub fn parse_trashinfo(info_path: &Path) -> (String, String) {
    let mut original = String::new();
    let mut deleted = String::new();
    let Ok(text) = fs::read_to_string(info_path) else {
        return (original, deleted);
    };
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("Path=") {
            original = percent_encoding::percent_decode_str(rest)
                .decode_utf8_lossy()
                .into_owned();
        } else if let Some(rest) = line.strip_prefix("DeletionDate=") {
            deleted = rest.to_string();
        }
    }
    (original, deleted)
}

pub fn list_trash() {
    let root = trash_root();
    let files_dir = root.join("files");
    let info_dir = root.join("info");
    if !files_dir.is_dir() {
        out_ok(serde_json::json!({
            "ok": true,
            "path": "trash://",
            "entries": [],
            "isTrash": true,
        }));
        return;
    }

    let children = match fs::read_dir(&files_dir) {
        Ok(rd) => rd,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
            err_exit("Permission denied: Trash");
        }
        Err(e) => err_exit(&e.to_string()),
    };

    let mut entries = Vec::new();
    for child in children.flatten() {
        let name = child.file_name().to_string_lossy().into_owned();
        let path = child.path();
        let (original, _) = parse_trashinfo(&info_dir.join(format!("{name}.trashinfo")));
        if let Some(e) = build_trash_list_entry(&path, &name, &original) {
            entries.push(e);
        }
    }

    entries.sort_by(|a, b| {
        let a_dir = a.get("isDir").and_then(|v| v.as_bool()).unwrap_or(false);
        let b_dir = b.get("isDir").and_then(|v| v.as_bool()).unwrap_or(false);
        let a_name = a
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        let b_name = b
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        (!a_dir, a_name).cmp(&(!b_dir, b_name))
    });

    out_ok(serde_json::json!({
        "ok": true,
        "path": "trash://",
        "entries": entries,
        "isTrash": true,
    }));
}

fn unique_trash_name(files_dir: &Path, base: &str) -> String {
    let candidate = files_dir.join(base);
    if !candidate.exists() {
        return base.to_string();
    }
    let path = Path::new(base);
    let stem = path
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| base.to_string());
    let ext = path
        .extension()
        .map(|e| format!(".{}", e.to_string_lossy()))
        .unwrap_or_default();
    for n in 1..10_000 {
        let name = format!("{stem}.{n}{ext}");
        if !files_dir.join(&name).exists() {
            return name;
        }
    }
    format!("{stem}.{}", std::process::id())
}

fn write_trashinfo(info_path: &Path, original: &str) -> std::io::Result<()> {
    let encoded = utf8_percent_encode(original, PATH_ENCODE).to_string();
    let date = Local::now().format("%Y-%m-%dT%H:%M:%S").to_string();
    let mut f = fs::File::create(info_path)?;
    writeln!(f, "[Trash Info]")?;
    writeln!(f, "Path={encoded}")?;
    writeln!(f, "DeletionDate={date}")?;
    Ok(())
}

fn trash_one(path: &Path) -> Result<(String, PathBuf, String), String> {
    let root = trash_root();
    let files_dir = root.join("files");
    let info_dir = root.join("info");
    fs::create_dir_all(&files_dir).map_err(|e| e.to_string())?;
    fs::create_dir_all(&info_dir).map_err(|e| e.to_string())?;

    let original = path
        .canonicalize()
        .unwrap_or_else(|_| path.to_path_buf())
        .to_string_lossy()
        .into_owned();
    let base = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "item".into());
    let trash_name = unique_trash_name(&files_dir, &base);
    let dest = files_dir.join(&trash_name);
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    // Write trashinfo first (spec recommends this order for crash safety)
    write_trashinfo(&info_path, &original).map_err(|e| e.to_string())?;
    if let Err(e) = fs::rename(path, &dest) {
        // Cross-device: copy then remove
        if path.is_dir() && !path.is_symlink() {
            copy_dir_recursive(path, &dest).map_err(|e| e.to_string())?;
            let _ = fs::remove_dir_all(path);
        } else {
            fs::copy(path, &dest).map_err(|err| format!("{e}; copy: {err}"))?;
            let _ = fs::remove_file(path);
        }
    }
    Ok((original, dest, trash_name))
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> std::io::Result<()> {
    fs::create_dir_all(dst)?;
    for ent in fs::read_dir(src)? {
        let ent = ent?;
        let from = ent.path();
        let to = dst.join(ent.file_name());
        if from.is_dir() && !from.is_symlink() {
            copy_dir_recursive(&from, &to)?;
        } else if from.is_symlink() {
            let target = fs::read_link(&from)?;
            std::os::unix::fs::symlink(target, &to)?;
        } else {
            fs::copy(&from, &to)?;
        }
    }
    Ok(())
}

pub fn do_trash(paths: &[String]) {
    let mut items = Vec::new();
    for raw in paths {
        let p = expand_user(raw);
        if !p.exists() {
            err_exit(&format!("Not found: {raw}"));
        }
        match trash_one(&p) {
            Ok((original, files_path, name)) => {
                items.push(serde_json::json!({
                    "uri": format!("trash:///{name}"),
                    "trashName": name,
                    "original": original,
                    "name": Path::new(&original).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default(),
                    "trashPath": files_path.to_string_lossy(),
                }));
            }
            Err(e) => err_exit(&e),
        }
    }
    out_ok(serde_json::json!({
        "ok": true,
        "count": paths.len(),
        "items": items,
    }));
}

fn trash_name_from_uri(uri: &str) -> String {
    let mut u = uri.trim().to_string();
    for prefix in ["trash:///", "trash://", "trash:/"] {
        if let Some(rest) = u.strip_prefix(prefix) {
            u = rest.to_string();
            break;
        }
    }
    let decoded = percent_encoding::percent_decode_str(&u)
        .decode_utf8_lossy()
        .into_owned();
    Path::new(&decoded)
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or(decoded)
}

fn find_trash_entry_for_original(original: &str) -> Option<(PathBuf, PathBuf, String)> {
    let info_dir = trash_root().join("info");
    let files_dir = trash_root().join("files");
    if !info_dir.is_dir() {
        return None;
    }
    let expanded = expand_user(original);
    let mut wanted = vec![expanded.to_string_lossy().into_owned()];
    if let Ok(c) = expanded.canonicalize() {
        wanted.push(c.to_string_lossy().into_owned());
    }

    let mut best = None;
    let mut best_mtime = -1.0f64;
    let Ok(rd) = fs::read_dir(&info_dir) else {
        return None;
    };
    for ent in rd.flatten() {
        let info_path = ent.path();
        if info_path.extension().and_then(|e| e.to_str()) != Some("trashinfo") {
            continue;
        }
        let (orig, _) = parse_trashinfo(&info_path);
        if !wanted.iter().any(|w| w == &orig) {
            continue;
        }
        let name = info_path
            .file_stem()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_default();
        let files_path = files_dir.join(&name);
        if !files_path.exists() {
            continue;
        }
        let mtime = info_path
            .metadata()
            .ok()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs_f64())
            .unwrap_or(0.0);
        if mtime >= best_mtime {
            best_mtime = mtime;
            best = Some((files_path, info_path, name));
        }
    }
    best
}

fn restore_trash_entry(files_path: &Path, info_path: &Path, original: &str) -> String {
    let dst = expand_user(original);
    if dst.exists() {
        err_exit(&format!("Already exists: {}", dst.display()));
    }
    if !files_path.exists() {
        err_exit(&format!("Missing trash file: {}", files_path.display()));
    }
    if let Some(parent) = dst.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if fs::rename(files_path, &dst).is_err() {
        if files_path.is_dir() && !files_path.is_symlink() {
            if let Err(e) = copy_dir_recursive(files_path, &dst) {
                err_exit(&e.to_string());
            }
            let _ = fs::remove_dir_all(files_path);
        } else {
            if let Err(e) = fs::copy(files_path, &dst) {
                err_exit(&e.to_string());
            }
            let _ = fs::remove_file(files_path);
        }
    }
    let _ = fs::remove_file(info_path);
    dst.to_string_lossy().into_owned()
}

pub fn do_restore(uris: &[String]) {
    let mut restored = Vec::new();
    let files_dir = trash_root().join("files");
    let info_dir = trash_root().join("info");

    for uri in uris {
        let name = trash_name_from_uri(uri);
        let info_path = info_dir.join(format!("{name}.trashinfo"));
        let files_path = files_dir.join(&name);

        if !name.is_empty() && info_path.is_file() && files_path.exists() {
            let (original, _) = parse_trashinfo(&info_path);
            if !original.is_empty() {
                restored.push(restore_trash_entry(&files_path, &info_path, &original));
                continue;
            }
        }

        if !uri.is_empty() && !uri.starts_with("trash:") {
            if let Some((fp, ip, _)) = find_trash_entry_for_original(uri) {
                let (orig, _) = parse_trashinfo(&ip);
                let orig = if orig.is_empty() {
                    uri.clone()
                } else {
                    orig
                };
                restored.push(restore_trash_entry(&fp, &ip, &orig));
                continue;
            }
        }

        // Fallback to gio if available
        let status = Command::new("gio").args(["trash", "--restore", uri]).status();
        match status {
            Ok(s) if s.success() => restored.push(uri.clone()),
            Ok(_) | Err(_) => err_exit(&format!("Cannot restore {uri}")),
        }
    }

    out_ok(serde_json::json!({
        "ok": true,
        "count": restored.len(),
        "uris": restored,
        "paths": restored,
    }));
}

fn wipe_dir_contents(directory: &Path) -> usize {
    let mut removed = 0;
    let Ok(rd) = fs::read_dir(directory) else {
        return 0;
    };
    for child in rd.flatten() {
        let path = child.path();
        let ok = if path.is_dir() && !path.is_symlink() {
            fs::remove_dir_all(&path).is_ok()
        } else {
            fs::remove_file(&path).is_ok()
        };
        if ok {
            removed += 1;
        }
    }
    removed
}

pub fn do_empty_trash() {
    let _ = Command::new("gio").args(["trash", "--empty"]).status();
    let root = trash_root();
    let mut removed = 0;
    for sub in ["files", "info", "expunged"] {
        removed += wipe_dir_contents(&root.join(sub));
    }
    out_ok(serde_json::json!({
        "ok": true,
        "emptied": true,
        "count": removed,
    }));
}

pub fn trash_original(path: &Path) -> String {
    let files_dir = trash_root().join("files");
    let parent = match path.parent() {
        Some(p) => p,
        None => return String::new(),
    };
    let Ok(parent_c) = parent.canonicalize() else {
        return String::new();
    };
    let Ok(files_c) = files_dir.canonicalize() else {
        return String::new();
    };
    if parent_c != files_c {
        return String::new();
    }
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let (original, _) = parse_trashinfo(&trash_root().join("info").join(format!("{name}.trashinfo")));
    original
}
