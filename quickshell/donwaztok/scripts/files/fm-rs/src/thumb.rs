//! Thumbnail generation: PE icons, AppImage, desktop, linux bin, image convert.

use crate::entry::{
    resolve_desktop_file_icon, resolve_linux_bin_icon, suffix_lower, PE_ICON_EXTS, SCRIPT_EXTS,
    THUMBNAIL_CONVERT_EXTS, THUMBNAIL_EXTS,
};
use crate::protocol::{err_exit, expand_user, out_ok};
use image::imageops::FilterType;
use image::ImageReader;
use std::fs::{self, File};
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;

fn resize_image_to(src: &Path, dest: &Path, px: u32) -> Result<(), String> {
    // Prefer pure Rust image crate; fall back to magick for svg/xpm/avif/jxl
    let ext = src
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    if matches!(ext.as_str(), "svg" | "xpm" | "avif" | "jxl") {
        return magick_resize(src, dest, px);
    }

    match ImageReader::open(src)
        .map_err(|e| e.to_string())?
        .with_guessed_format()
        .map_err(|e| e.to_string())?
        .decode()
    {
        Ok(img) => {
            let resized = img.resize(px, px, FilterType::Lanczos3);
            if let Some(parent) = dest.parent() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            resized
                .save(dest)
                .map_err(|e| e.to_string())?;
            Ok(())
        }
        Err(_) => magick_resize(src, dest, px),
    }
}

fn magick_resize(src: &Path, dest: &Path, px: u32) -> Result<(), String> {
    if let Some(parent) = dest.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let status = Command::new("magick")
        .arg(src)
        .arg("-resize")
        .arg(format!("{px}x{px}"))
        .arg(dest)
        .status()
        .map_err(|e| e.to_string())?;
    if !status.success() || !dest.is_file() {
        return Err("magick failed converting icon".into());
    }
    Ok(())
}

fn pe_rva_to_off(sections: &[(u32, u32, u32)], rva: u32) -> Option<usize> {
    for &(vrva, span, rawptr) in sections {
        if vrva <= rva && rva < vrva + span {
            return Some((rawptr + (rva - vrva)) as usize);
        }
    }
    None
}

fn pe_parse_resource_dir(
    data: &[u8],
    sections: &[(u32, u32, u32)],
    dir_rva: u32,
) -> Vec<(u32, u32)> {
    let Some(off) = pe_rva_to_off(sections, dir_rva) else {
        return vec![];
    };
    if off + 16 > data.len() {
        return vec![];
    }
    let named = u16::from_le_bytes([data[off + 12], data[off + 13]]) as usize;
    let ids = u16::from_le_bytes([data[off + 14], data[off + 15]]) as usize;
    let mut entries = Vec::new();
    let base = off + 16;
    for i in 0..(named + ids) {
        let e = base + i * 8;
        if e + 8 > data.len() {
            break;
        }
        let name_or_id = u32::from_le_bytes(data[e..e + 4].try_into().unwrap());
        let offset = u32::from_le_bytes(data[e + 4..e + 8].try_into().unwrap());
        entries.push((name_or_id, offset));
    }
    entries
}

fn extract_pe_icon_bytes(exe_path: &Path) -> Option<Vec<u8>> {
    let data = fs::read(exe_path).ok()?;
    if data.len() < 0x40 || &data[..2] != b"MZ" {
        return None;
    }
    let e_lfanew = u32::from_le_bytes(data[0x3C..0x40].try_into().ok()?) as usize;
    if e_lfanew + 24 > data.len() || &data[e_lfanew..e_lfanew + 4] != b"PE\0\0" {
        return None;
    }
    let coff = e_lfanew + 4;
    let num_sections = u16::from_le_bytes(data[coff + 2..coff + 4].try_into().ok()?) as usize;
    let opt_size = u16::from_le_bytes(data[coff + 16..coff + 18].try_into().ok()?) as usize;
    let opt = coff + 20;
    if opt + 2 > data.len() {
        return None;
    }
    let magic = u16::from_le_bytes(data[opt..opt + 2].try_into().ok()?);
    let dd_off = opt + if magic == 0x20B { 112 } else { 96 };
    if dd_off + 24 > data.len() {
        return None;
    }
    let res_rva = u32::from_le_bytes(data[dd_off + 16..dd_off + 20].try_into().ok()?);
    if res_rva == 0 {
        return None;
    }
    let sec_off = opt + opt_size;
    let mut sections = Vec::new();
    for i in 0..num_sections {
        let o = sec_off + i * 40;
        if o + 40 > data.len() {
            break;
        }
        let vsize = u32::from_le_bytes(data[o + 8..o + 12].try_into().ok()?);
        let vrva = u32::from_le_bytes(data[o + 12..o + 16].try_into().ok()?);
        let rawsize = u32::from_le_bytes(data[o + 16..o + 20].try_into().ok()?);
        let rawptr = u32::from_le_bytes(data[o + 20..o + 24].try_into().ok()?);
        sections.push((vrva, vsize.max(rawsize), rawptr));
    }

    const RT_ICON: u32 = 3;
    const RT_GROUP_ICON: u32 = 14;

    let is_subdir = |offset_field: u32| offset_field & 0x8000_0000 != 0;
    let child_rva = |offset_field: u32| res_rva + (offset_field & 0x7FFF_FFFF);

    let mut icon_blobs: std::collections::HashMap<u32, Vec<u8>> = std::collections::HashMap::new();
    let mut groups: Vec<Vec<u8>> = Vec::new();

    for (tid, toff) in pe_parse_resource_dir(&data, &sections, res_rva) {
        let type_id = tid & 0xFFFF;
        if !is_subdir(toff) {
            continue;
        }
        for (nid, noff) in pe_parse_resource_dir(&data, &sections, child_rva(toff)) {
            if !is_subdir(noff) {
                continue;
            }
            for (_lid, loff) in pe_parse_resource_dir(&data, &sections, child_rva(noff)) {
                if is_subdir(loff) {
                    continue;
                }
                let Some(entry_off) = pe_rva_to_off(&sections, child_rva(loff)) else {
                    continue;
                };
                if entry_off + 8 > data.len() {
                    continue;
                }
                let data_rva =
                    u32::from_le_bytes(data[entry_off..entry_off + 4].try_into().ok()?);
                let size = u32::from_le_bytes(data[entry_off + 4..entry_off + 8].try_into().ok()?)
                    as usize;
                let Some(file_off) = pe_rva_to_off(&sections, data_rva) else {
                    continue;
                };
                if file_off + size > data.len() {
                    continue;
                }
                let blob = data[file_off..file_off + size].to_vec();
                if type_id == RT_GROUP_ICON {
                    groups.push(blob);
                } else if type_id == RT_ICON {
                    icon_blobs.insert(nid & 0xFFFF, blob);
                }
            }
        }
    }

    if icon_blobs.is_empty() {
        return None;
    }

    let mut best_id = None;
    let mut best_score = -1i64;
    let mut best_wh = (32u32, 32u32);
    for gblob in &groups {
        if gblob.len() < 6 {
            continue;
        }
        let count = u16::from_le_bytes([gblob[4], gblob[5]]) as usize;
        for i in 0..count {
            let o = 6 + i * 14;
            if o + 14 > gblob.len() {
                break;
            }
            let mut w = gblob[o] as u32;
            let mut h = gblob[o + 1] as u32;
            let bpp = u16::from_le_bytes([gblob[o + 6], gblob[o + 7]]) as i64;
            let icon_id = u16::from_le_bytes([gblob[o + 12], gblob[o + 13]]) as u32;
            if w == 0 {
                w = 256;
            }
            if h == 0 {
                h = 256;
            }
            let score = (w as i64) * (h as i64) * bpp.max(1).max(32);
            if score > best_score && icon_blobs.contains_key(&icon_id) {
                best_score = score;
                best_id = Some(icon_id);
                best_wh = (w, h);
            }
        }
    }

    let best_id = best_id.or_else(|| icon_blobs.keys().next().copied())?;
    let img = icon_blobs.get(&best_id)?;
    let (w, h) = best_wh;

    let mut ico = Vec::new();
    ico.extend_from_slice(&0u16.to_le_bytes());
    ico.extend_from_slice(&1u16.to_le_bytes());
    ico.extend_from_slice(&1u16.to_le_bytes());
    ico.push(if w >= 256 { 0 } else { w as u8 });
    ico.push(if h >= 256 { 0 } else { h as u8 });
    ico.push(0);
    ico.push(0);
    ico.extend_from_slice(&1u16.to_le_bytes());
    ico.extend_from_slice(&32u16.to_le_bytes());
    ico.extend_from_slice(&(img.len() as u32).to_le_bytes());
    ico.extend_from_slice(&22u32.to_le_bytes());
    ico.extend_from_slice(img);
    Some(ico)
}

fn score_appimage_icon_path(name: &str) -> i32 {
    let low = name.to_lowercase();
    let mut score = 0i32;
    if let Some(idx) = low.find('x') {
        // look for /NNNxNNN/
        for part in low.split('/') {
            if let Some((a, b)) = part.split_once('x') {
                if b.chars().all(|c| c.is_ascii_digit()) {
                    if let Ok(n) = a.parse::<i32>() {
                        score += n;
                    }
                }
            }
            let _ = idx;
        }
    }
    if low.contains("/apps/") {
        score += 10000;
    }
    if low.ends_with(".png") {
        score += 80;
    } else if low.ends_with(".svg") {
        score += 60;
    }
    if name.ends_with(".DirIcon") || low.ends_with("/.diricon") {
        score += 3000;
    }
    if !name.contains('/') && (low.ends_with(".png") || low.ends_with(".svg")) {
        score += 1500;
    }
    score
}

fn appimage_list_paths(ai: &Path) -> Vec<String> {
    let out = Command::new("7z")
        .args(["l", "-ba"])
        .arg(ai)
        .output();
    let Ok(out) = out else {
        return vec![];
    };
    let mut paths = Vec::new();
    for line in String::from_utf8_lossy(&out.stdout).lines() {
        let parts: Vec<_> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }
        let name = parts[parts.len() - 1];
        let low = name.to_lowercase();
        if low.ends_with(".png")
            || low.ends_with(".svg")
            || low.ends_with(".xpm")
            || low.ends_with(".ico")
            || name.ends_with(".DirIcon")
            || low.ends_with("/.diricon")
        {
            paths.push(name.to_string());
        }
    }
    paths
}

fn extract_appimage_icon_file(ai: &Path) -> Option<PathBuf> {
    let mut candidates = appimage_list_paths(ai);
    if candidates.is_empty() {
        return None;
    }
    candidates.sort_by_key(|n| std::cmp::Reverse(score_appimage_icon_path(n)));
    let tmp = std::env::temp_dir().join(format!(
        "fm-appimage-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ));
    let _ = fs::create_dir_all(&tmp);
    for rel in candidates.iter().take(12) {
        let _ = Command::new("7z")
            .args(["e", "-y"])
            .arg(format!("-o{}", tmp.display()))
            .arg(ai)
            .arg(rel)
            .output();
        // Resolve symlink .DirIcon
        if let Ok(rd) = fs::read_dir(&tmp) {
            for ent in rd.flatten() {
                let p = ent.path();
                if p.is_symlink() {
                    if let Ok(target) = fs::read_link(&p) {
                        let _ = Command::new("7z")
                            .args(["e", "-y"])
                            .arg(format!("-o{}", tmp.display()))
                            .arg(ai)
                            .arg(&target)
                            .output();
                    }
                }
            }
        }
        let pngs: Vec<_> = WalkFiles::new(&tmp)
            .filter(|f| {
                let s = f
                    .extension()
                    .map(|e| e.to_string_lossy().to_lowercase())
                    .unwrap_or_default();
                matches!(s.as_str(), "png" | "svg" | "xpm" | "ico") && !f.is_symlink()
            })
            .collect();
        if pngs.is_empty() {
            clear_dir(&tmp);
            continue;
        }
        let best = pngs
            .iter()
            .max_by_key(|f| f.metadata().map(|m| m.len()).unwrap_or(0))?;
        let out = tmp.join(format!(
            "icon.{}",
            best.extension()
                .map(|e| e.to_string_lossy().to_lowercase())
                .unwrap_or_else(|| "png".into())
        ));
        if best != &out {
            let _ = fs::copy(best, &out);
        }
        return Some(out);
    }
    let _ = fs::remove_dir_all(&tmp);
    None
}

struct WalkFiles {
    stack: Vec<PathBuf>,
}

impl WalkFiles {
    fn new(root: &Path) -> Self {
        Self {
            stack: vec![root.to_path_buf()],
        }
    }
}

impl Iterator for WalkFiles {
    type Item = PathBuf;
    fn next(&mut self) -> Option<Self::Item> {
        while let Some(p) = self.stack.pop() {
            if p.is_dir() && !p.is_symlink() {
                if let Ok(rd) = fs::read_dir(&p) {
                    for ent in rd.flatten() {
                        self.stack.push(ent.path());
                    }
                }
            } else if p.is_file() || (p.exists() && !p.is_dir()) {
                return Some(p);
            }
        }
        None
    }
}

fn clear_dir(tmp: &Path) {
    if let Ok(rd) = fs::read_dir(tmp) {
        for ent in rd.flatten() {
            let p = ent.path();
            if p.is_dir() {
                let _ = fs::remove_dir_all(&p);
            } else {
                let _ = fs::remove_file(&p);
            }
        }
    }
}

pub fn do_thumb(path: &str, dest: &str, size: i32) {
    let src = expand_user(path);
    let out_path = expand_user(dest);
    if !src.is_file() {
        err_exit(&format!("Not a file: {path}"));
    }
    if let Some(parent) = out_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    // Hot path: reuse cached PNG
    if out_path.is_file() {
        if let Ok(meta) = out_path.metadata() {
            if meta.len() > 0 {
                out_ok(serde_json::json!({
                    "ok": true,
                    "path": out_path.to_string_lossy(),
                    "kind": "cached",
                }));
                return;
            }
        }
    }
    let px = if size <= 0 {
        64
    } else {
        size.clamp(16, 256) as u32
    };
    let suffix = suffix_lower(&src);
    let name_l = src
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();

    let finish_from_image = |img: &Path, kind: &str| {
        if let Err(e) = resize_image_to(img, &out_path, px) {
            err_exit(&e);
        }
        out_ok(serde_json::json!({
            "ok": true,
            "path": out_path.to_string_lossy(),
            "kind": kind,
        }));
    };

    if PE_ICON_EXTS.contains(&suffix.as_str()) {
        let Some(ico) = extract_pe_icon_bytes(&src) else {
            err_exit("No icon resource in executable");
        };
        let tmp_ico = std::env::temp_dir().join(format!("fm-pe-{}.ico", std::process::id()));
        {
            let mut f = File::create(&tmp_ico).unwrap_or_else(|e| err_exit(&e.to_string()));
            let _ = f.write_all(&ico);
        }
        let r = resize_image_to(&tmp_ico, &out_path, px);
        let _ = fs::remove_file(&tmp_ico);
        if let Err(e) = r {
            err_exit(&e);
        }
        out_ok(serde_json::json!({
            "ok": true,
            "path": out_path.to_string_lossy(),
            "kind": "exe",
        }));
        return;
    }

    if name_l.ends_with(".appimage") {
        let Some(extracted) = extract_appimage_icon_file(&src) else {
            err_exit("No icon found in AppImage");
        };
        let tmp_root = extracted.parent().map(|p| p.to_path_buf());
        finish_from_image(&extracted, "appimage");
        if let Some(root) = tmp_root {
            let _ = fs::remove_dir_all(root);
        }
        return;
    }

    if suffix == ".desktop" {
        let Some(icon_path) = resolve_desktop_file_icon(&src, px) else {
            err_exit("No Icon= in desktop file / theme");
        };
        finish_from_image(&icon_path, "desktop");
        return;
    }

    let executable = src
        .metadata()
        .map(|m| m.permissions().mode() & 0o111 != 0)
        .unwrap_or(false);
    if executable
        && !SCRIPT_EXTS.contains(&suffix.as_str())
        && !THUMBNAIL_EXTS.contains(&suffix.as_str())
    {
        if let Some(icon_path) = resolve_linux_bin_icon(&src, px) {
            finish_from_image(&icon_path, "linux");
            return;
        }
    }

    if suffix == ".ico" || THUMBNAIL_CONVERT_EXTS.contains(&suffix.as_str()) {
        if let Err(e) = resize_image_to(&src, &out_path, px) {
            err_exit(&e);
        }
        out_ok(serde_json::json!({
            "ok": true,
            "path": out_path.to_string_lossy(),
            "kind": "image",
        }));
        return;
    }

    // Also handle plain thumbnail image types if called directly
    if THUMBNAIL_EXTS.contains(&suffix.as_str()) {
        if let Err(e) = resize_image_to(&src, &out_path, px) {
            err_exit(&e);
        }
        out_ok(serde_json::json!({
            "ok": true,
            "path": out_path.to_string_lossy(),
            "kind": "image",
        }));
        return;
    }

    err_exit(&format!(
        "Unsupported thumb type: {}",
        if suffix.is_empty() {
            name_l
        } else {
            suffix
        }
    ));
}
