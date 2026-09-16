//! Directory and trash listing.

use crate::entry::{
    entry_flags, mime_for, suffix_lower, suffix_no_dot, ARCHIVE_EXTS, IMAGE_EXTS,
};
use crate::protocol::{err_exit, expand_user, out_ok};
use crate::trash::{is_trash_uri, list_trash};
use serde::Serialize;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ListEntry {
    name: String,
    path: String,
    is_dir: bool,
    is_symlink: bool,
    is_trash: bool,
    size: u64,
    mtime: i64,
    mime_type: String,
    suffix: String,
    is_image: bool,
    can_thumbnail: bool,
    thumb_kind: String,
    is_archive: bool,
    is_executable: bool,
    is_app_image: bool,
    is_windows_exe: bool,
    is_desktop: bool,
    is_linux_bin: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ListResult {
    ok: bool,
    path: String,
    entries: Vec<ListEntry>,
    is_trash: bool,
}

pub fn list_dir(path: &str, show_hidden: bool) {
    if is_trash_uri(path) {
        list_trash();
        return;
    }

    let root = expand_user(path);
    if !root.is_dir() {
        err_exit(&format!("Not a directory: {path}"));
    }

    let children = match fs::read_dir(&root) {
        Ok(rd) => rd,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
            err_exit(&format!("Permission denied: {path}"));
        }
        Err(e) => err_exit(&e.to_string()),
    };

    let mut entries = Vec::new();
    for child in children.flatten() {
        let name = child.file_name().to_string_lossy().into_owned();
        if !show_hidden && name.starts_with('.') {
            continue;
        }
        let path_buf = child.path();
        match build_entry(&path_buf, &name, false) {
            Some(e) => entries.push(e),
            None => continue,
        }
    }

    entries.sort_by(|a, b| {
        (!a.is_dir, a.name.to_lowercase()).cmp(&(!b.is_dir, b.name.to_lowercase()))
    });

    let resolved = root
        .canonicalize()
        .unwrap_or(root)
        .to_string_lossy()
        .into_owned();

    out_ok(ListResult {
        ok: true,
        path: resolved,
        entries,
        is_trash: false,
    });
}

fn build_entry(path: &Path, name: &str, is_trash: bool) -> Option<ListEntry> {
    let meta = fs::symlink_metadata(path).ok()?;
    let is_symlink = meta.file_type().is_symlink();
    let mut is_dir = meta.is_dir() && !is_symlink;
    if is_symlink {
        is_dir = fs::canonicalize(path).map(|p| p.is_dir()).unwrap_or(false);
    }
    let size = if is_dir { 0 } else { meta.len() };
    let mime = mime_for(path, is_dir);
    let flags = entry_flags(path, is_dir);
    let suffix_dot = suffix_lower(path);
    Some(ListEntry {
        name: name.to_string(),
        path: path.to_string_lossy().into_owned(),
        is_dir,
        is_symlink,
        is_trash,
        size,
        mtime: meta.mtime(),
        mime_type: mime,
        suffix: suffix_no_dot(path),
        is_image: !is_dir && IMAGE_EXTS.contains(&suffix_dot.as_str()),
        can_thumbnail: flags.can_thumbnail,
        thumb_kind: flags.thumb_kind,
        is_archive: !is_dir && ARCHIVE_EXTS.contains(&suffix_dot.as_str()),
        is_executable: flags.is_executable,
        is_app_image: flags.is_appimage,
        is_windows_exe: flags.is_windows_exe,
        is_desktop: flags.is_desktop,
        is_linux_bin: flags.is_linux_bin,
    })
}

/// Used by trash module to share entry building for trash items.
pub fn build_trash_list_entry(
    path: &Path,
    name: &str,
    original_path: &str,
) -> Option<serde_json::Value> {
    let meta = fs::symlink_metadata(path).ok()?;
    let is_symlink = meta.file_type().is_symlink();
    let mut is_dir = meta.is_dir() && !is_symlink;
    if is_symlink {
        is_dir = fs::canonicalize(path).map(|p| p.is_dir()).unwrap_or(false);
    }
    let size = if is_dir { 0 } else { meta.len() };
    let mime = mime_for(path, is_dir);
    let flags = entry_flags(path, is_dir);
    let suffix_dot = suffix_lower(path);
    Some(serde_json::json!({
        "name": name,
        "path": path.to_string_lossy(),
        "trashUri": format!("trash:///{name}"),
        "originalPath": original_path,
        "isDir": is_dir,
        "isSymlink": is_symlink,
        "isTrash": true,
        "size": size,
        "mtime": meta.mtime(),
        "mimeType": mime,
        "suffix": suffix_no_dot(path),
        "isImage": !is_dir && IMAGE_EXTS.contains(&suffix_dot.as_str()),
        "canThumbnail": flags.can_thumbnail,
        "thumbKind": flags.thumb_kind,
        "isArchive": false,
        "isWindowsExe": flags.is_windows_exe,
        "isDesktop": flags.is_desktop,
        "isLinuxBin": flags.is_linux_bin,
    }))
}
