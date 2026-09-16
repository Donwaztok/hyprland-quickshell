//! Smart archive extract (zip via crate; 7z via 7z/bsdtar).

use crate::entry::ARCHIVE_EXTS;
use crate::protocol::{err_exit, expand_user, out_ok, progress};
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;
use walkdir::WalkDir;
use zip::ZipArchive;

pub fn find_7z() -> Option<String> {
    for name in ["7z", "7za", "7zr"] {
        if let Ok(p) = which::which(name) {
            return Some(p.to_string_lossy().into_owned());
        }
    }
    None
}

fn find_bsdtar() -> Option<String> {
    which::which("bsdtar")
        .or_else(|_| which::which("tar"))
        .ok()
        .map(|p| p.to_string_lossy().into_owned())
}

fn zip_top_level(archive: &Path) -> Result<(Vec<String>, Vec<String>), String> {
    let f = File::open(archive).map_err(|e| e.to_string())?;
    let mut zf = ZipArchive::new(f).map_err(|e| e.to_string())?;
    let mut dirs = std::collections::HashSet::new();
    let mut files = std::collections::HashSet::new();
    for i in 0..zf.len() {
        let info = zf.by_index(i).map_err(|e| e.to_string())?;
        let name = info.name().replace('\\', "/");
        if name.is_empty() || name.starts_with("__MACOSX") {
            continue;
        }
        let parts: Vec<_> = name.split('/').filter(|p| !p.is_empty()).collect();
        if parts.is_empty() {
            continue;
        }
        if parts.len() == 1 && !info.is_dir() {
            files.insert(parts[0].to_string());
        } else {
            dirs.insert(parts[0].to_string());
        }
    }
    for f in files.clone() {
        if dirs.contains(&f) {
            files.remove(&f);
        }
    }
    let mut d: Vec<_> = dirs.into_iter().collect();
    let mut f: Vec<_> = files.into_iter().collect();
    d.sort();
    f.sort();
    Ok((d, f))
}

fn seven_top_level_via_7z(archive: &Path, seven: &str) -> Result<(Vec<String>, Vec<String>), String> {
    let out = Command::new(seven)
        .args(["l", "-ba", "-slt"])
        .arg(archive)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!("7z list failed: {}", out.status));
    }
    let raw = String::from_utf8_lossy(&out.stdout);
    let mut dirs = std::collections::HashSet::new();
    let mut files = std::collections::HashSet::new();
    let mut path = String::new();
    let mut is_dir = false;
    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix("Path = ") {
            path = rest.replace('\\', "/");
        } else if let Some(rest) = line.strip_prefix("Folder = ") {
            let v = rest.trim().to_lowercase();
            is_dir = matches!(v.as_str(), "+" | "true" | "yes" | "1");
        } else if line.is_empty() && !path.is_empty() {
            if path == "." || path.starts_with("__MACOSX") {
                path.clear();
                continue;
            }
            let parts: Vec<_> = path.split('/').filter(|p| !p.is_empty()).collect();
            if !parts.is_empty() {
                if parts.len() == 1 && !is_dir {
                    files.insert(parts[0].to_string());
                } else {
                    dirs.insert(parts[0].to_string());
                }
            }
            path.clear();
            is_dir = false;
        }
    }
    for f in files.clone() {
        if dirs.contains(&f) {
            files.remove(&f);
        }
    }
    let mut d: Vec<_> = dirs.into_iter().collect();
    let mut f: Vec<_> = files.into_iter().collect();
    d.sort();
    f.sort();
    Ok((d, f))
}

fn seven_top_level_via_bsdtar(archive: &Path, tar: &str) -> Result<(Vec<String>, Vec<String>), String> {
    let out = Command::new(tar)
        .args(["-tf"])
        .arg(archive)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!("Archive list failed: {}", out.status));
    }
    let raw = String::from_utf8_lossy(&out.stdout);
    let mut dirs = std::collections::HashSet::new();
    let mut files = std::collections::HashSet::new();
    for line in raw.lines() {
        let name = line.trim().replace('\\', "/");
        if name.is_empty() || name.starts_with("__MACOSX") {
            continue;
        }
        let is_dir = name.ends_with('/');
        let parts: Vec<_> = name.split('/').filter(|p| !p.is_empty()).collect();
        if parts.is_empty() {
            continue;
        }
        if parts.len() == 1 && !is_dir {
            files.insert(parts[0].to_string());
        } else {
            dirs.insert(parts[0].to_string());
        }
    }
    for f in files.clone() {
        if dirs.contains(&f) {
            files.remove(&f);
        }
    }
    let mut d: Vec<_> = dirs.into_iter().collect();
    let mut f: Vec<_> = files.into_iter().collect();
    d.sort();
    f.sort();
    Ok((d, f))
}

fn seven_top_level(archive: &Path) -> (Vec<String>, Vec<String>) {
    if let Some(seven) = find_7z() {
        match seven_top_level_via_7z(archive, &seven) {
            Ok(r) => return r,
            Err(e) => err_exit(&format!("7z list failed: {e}")),
        }
    }
    if let Some(tar) = find_bsdtar() {
        match seven_top_level_via_bsdtar(archive, &tar) {
            Ok(r) => return r,
            Err(e) => err_exit(&format!("Archive list failed: {e}")),
        }
    }
    err_exit("No archive tool found. Install 7zip (or p7zip) to extract .7z/.rar files.");
}

fn extract_zip(archive: &Path, dest: &Path) -> Result<(), String> {
    fs::create_dir_all(dest).map_err(|e| e.to_string())?;
    let f = File::open(archive).map_err(|e| e.to_string())?;
    let mut zf = ZipArchive::new(f).map_err(|e| e.to_string())?;
    let mut infos = Vec::new();
    for i in 0..zf.len() {
        let name = zf.by_index(i).map_err(|e| e.to_string())?.name().to_string();
        if !name.starts_with("__MACOSX") {
            infos.push(i);
        }
    }
    let mut total = 0u64;
    for &i in &infos {
        let info = zf.by_index(i).map_err(|e| e.to_string())?;
        total += info.size();
    }
    let total = total.max(1);
    let mut done = 0u64;
    for (idx, &i) in infos.iter().enumerate() {
        let mut info = zf.by_index(i).map_err(|e| e.to_string())?;
        let outpath = match info.enclosed_name() {
            Some(p) => dest.join(p),
            None => continue,
        };
        if info.is_dir() {
            fs::create_dir_all(&outpath).map_err(|e| e.to_string())?;
        } else {
            if let Some(parent) = outpath.parent() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            let mut outfile = File::create(&outpath).map_err(|e| e.to_string())?;
            std::io::copy(&mut info, &mut outfile).map_err(|e| e.to_string())?;
            done += info.size();
            let pct = (done as f64 / total as f64).max((idx + 1) as f64 / infos.len().max(1) as f64);
            let name = outpath
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default();
            progress(pct.min(0.95), &format!("Extracting {name}"));
        }
    }
    Ok(())
}

pub fn path_size(path: &Path) -> u64 {
    if path.is_file() {
        return path.metadata().map(|m| m.len()).unwrap_or(0);
    }
    WalkDir::new(path)
        .follow_links(false)
        .into_iter()
        .flatten()
        .filter(|e| e.file_type().is_file())
        .map(|e| e.metadata().map(|m| m.len()).unwrap_or(0))
        .sum()
}

fn seven_uncompressed_size(archive: &Path, seven: &str) -> u64 {
    let out = Command::new(seven)
        .args(["l", "-ba", "-slt"])
        .arg(archive)
        .output();
    let Ok(out) = out else {
        return 0;
    };
    let raw = String::from_utf8_lossy(&out.stdout);
    let mut total = 0u64;
    let mut path = String::new();
    let mut is_dir = false;
    let mut size = 0u64;
    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix("Path = ") {
            path = rest.replace('\\', "/");
            is_dir = false;
            size = 0;
        } else if let Some(rest) = line.strip_prefix("Folder = ") {
            let v = rest.trim().to_lowercase();
            is_dir = matches!(v.as_str(), "+" | "true" | "yes" | "1");
        } else if let Some(rest) = line.strip_prefix("Size = ") {
            size = rest.trim().parse().unwrap_or(0);
        } else if line.is_empty() && !path.is_empty() {
            if path != "."
                && !path.starts_with("__MACOSX")
                && !is_dir
                && !path.ends_with('/')
            {
                total += size;
            }
            path.clear();
            is_dir = false;
            size = 0;
        }
    }
    total
}

fn apply_backspaces(text: &str) -> String {
    let mut out = Vec::new();
    for ch in text.chars() {
        if ch == '\u{8}' {
            out.pop();
        } else if ch != '\r' {
            out.push(ch);
        }
    }
    out.into_iter().collect()
}

fn extract_7z_via_bsdtar(archive: &Path, dest: &Path, tar: &str) {
    let _ = fs::create_dir_all(dest);
    progress(0.08, "Extracting archive");
    let mut proc = Command::new(tar)
        .args(["-xf"])
        .arg(archive)
        .arg("-C")
        .arg(dest)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| err_exit(&e.to_string()));
    let mut last = 0.08f64;
    while proc.try_wait().ok().flatten().is_none() {
        thread::sleep(Duration::from_millis(150));
        last = (last + 0.04).min(0.9);
        progress(last, "Extracting archive");
    }
    let status = proc.wait().unwrap_or_else(|e| err_exit(&e.to_string()));
    if !status.success() {
        err_exit(&format!(
            "Archive extract failed: exit {}",
            status.code().unwrap_or(-1)
        ));
    }
    progress(0.96, "Finishing…");
}

fn extract_7z(archive: &Path, dest: &Path) {
    let _ = fs::create_dir_all(dest);
    let Some(seven) = find_7z() else {
        if let Some(tar) = find_bsdtar() {
            extract_7z_via_bsdtar(archive, dest, &tar);
            return;
        }
        err_exit("No archive tool found. Install 7zip (package: 7zip) to extract .7z/.rar files.");
    };

    let expected = seven_uncompressed_size(archive, &seven);
    progress(0.05, "Extracting archive");

    let mut proc = Command::new(&seven)
        .args(["x", "-y", "-bsp1", "-bso0", "-bse0"])
        .arg(format!("-o{}", dest.display()))
        .arg(archive)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap_or_else(|e| err_exit(&e.to_string()));

    let dest_c = dest.to_path_buf();
    let stop = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let stop2 = stop.clone();
    let last = std::sync::Arc::new(std::sync::Mutex::new(0.05f64));
    let last2 = last.clone();

    let poller = thread::spawn(move || {
        while !stop2.load(std::sync::atomic::Ordering::Relaxed) {
            thread::sleep(Duration::from_millis(120));
            let mut lb = last2.lock().unwrap();
            if expected <= 0 {
                *lb = (*lb + 0.03).min(0.9);
                progress(*lb, "Extracting archive");
                continue;
            }
            let cur = path_size(&dest_c) as f64;
            let pct = (cur / expected as f64).clamp(0.05, 0.95);
            if pct - *lb >= 0.01 || pct >= 0.95 {
                *lb = pct;
                progress(pct, "Extracting archive");
            }
        }
    });

    let mut raw = Vec::new();
    if let Some(mut stdout) = proc.stdout.take() {
        let mut buf = [0u8; 64];
        loop {
            match stdout.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    raw.extend_from_slice(&buf[..n]);
                    let text = apply_backspaces(&String::from_utf8_lossy(&raw));
                    if let Some(caps) = regex_last_pct(&text) {
                        let pct = (caps / 100.0).clamp(0.05, 0.95);
                        let mut lb = last.lock().unwrap();
                        if pct - *lb >= 0.01 || pct >= 0.95 {
                            *lb = pct;
                            progress(pct, "Extracting archive");
                        }
                    }
                }
                Err(_) => break,
            }
        }
    }

    stop.store(true, std::sync::atomic::Ordering::Relaxed);
    let _ = poller.join();
    let status = proc.wait().unwrap_or_else(|e| err_exit(&e.to_string()));
    if !status.success() {
        err_exit(&format!(
            "7z extract failed (exit {})",
            status.code().unwrap_or(-1)
        ));
    }
    progress(0.96, "Finishing…");
}

fn regex_last_pct(text: &str) -> Option<f64> {
    let mut last = None;
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i].is_ascii_digit() {
            let start = i;
            while i < bytes.len() && bytes[i].is_ascii_digit() {
                i += 1;
            }
            let num: f64 = std::str::from_utf8(&bytes[start..i])
                .ok()?
                .parse()
                .ok()?;
            while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                i += 1;
            }
            if i < bytes.len() && bytes[i] == b'%' {
                last = Some(num);
            }
        } else {
            i += 1;
        }
    }
    last
}

fn planned_extract_target(
    dest: &Path,
    archive_stem: &str,
    top_dirs: &[String],
    top_files: &[String],
) -> PathBuf {
    if top_dirs.len() == 1 && top_files.is_empty() {
        return dest.join(&top_dirs[0]);
    }
    if top_dirs.is_empty() && top_files.len() == 1 {
        return dest.join(&top_files[0]);
    }
    dest.join(archive_stem)
}

fn move_path(src: &Path, dst: &Path) -> Result<(), String> {
    if fs::rename(src, dst).is_ok() {
        return Ok(());
    }
    if src.is_dir() && !src.is_symlink() {
        copy_dir(src, dst)?;
        let _ = fs::remove_dir_all(src);
    } else {
        fs::copy(src, dst).map_err(|e| e.to_string())?;
        let _ = fs::remove_file(src);
    }
    Ok(())
}

fn copy_dir(src: &Path, dst: &Path) -> Result<(), String> {
    fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    for ent in fs::read_dir(src).map_err(|e| e.to_string())? {
        let ent = ent.map_err(|e| e.to_string())?;
        let from = ent.path();
        let to = dst.join(ent.file_name());
        if from.is_dir() && !from.is_symlink() {
            copy_dir(&from, &to)?;
        } else {
            fs::copy(&from, &to).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

pub fn smart_extract(archive_path: &str, dest_dir: Option<&str>) {
    let archive = expand_user(archive_path);
    let archive = archive.canonicalize().unwrap_or(archive);
    if !archive.is_file() {
        err_exit(&format!("Archive not found: {archive_path}"));
    }

    let dest = if let Some(d) = dest_dir {
        let p = expand_user(d);
        p.canonicalize().unwrap_or(p)
    } else {
        archive
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."))
    };
    if !dest.is_dir() {
        err_exit(&format!("Destination is not a directory: {}", dest.display()));
    }

    let mut ext = archive
        .extension()
        .map(|e| format!(".{}", e.to_string_lossy().to_lowercase()))
        .unwrap_or_default();
    if ext == ".7zip" {
        ext = ".7z".into();
    }
    if !ARCHIVE_EXTS.contains(&ext.as_str()) {
        err_exit(&format!("Unsupported archive type: {ext}"));
    }

    progress(0.02, "Inspecting archive…");
    let (top_dirs, top_files) = if ext == ".zip" {
        match zip_top_level(&archive) {
            Ok(r) => r,
            Err(e) => err_exit(&e),
        }
    } else {
        seven_top_level(&archive)
    };

    let base = archive
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "archive".into());
    let planned = planned_extract_target(&dest, &base, &top_dirs, &top_files);
    if planned.exists() {
        err_exit(&format!("Already exists: {}", planned.display()));
    }

    let tmp = tempfile_dir();
    if ext == ".zip" {
        if let Err(e) = extract_zip(&archive, &tmp) {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&e);
        }
    } else {
        extract_7z(&archive, &tmp);
    }

    for junk in WalkDir::new(&tmp).into_iter().flatten() {
        let name = junk.file_name().to_string_lossy();
        if name == "__MACOSX" && junk.file_type().is_dir() {
            let _ = fs::remove_dir_all(junk.path());
        }
        if name == ".DS_Store" {
            let _ = fs::remove_file(junk.path());
        }
    }

    let children: Vec<_> = fs::read_dir(&tmp)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.file_name().and_then(|n| n.to_str()) != Some("__MACOSX"))
        .collect();

    progress(0.97, "Placing files…");

    let result = if top_dirs.len() == 1
        && top_files.is_empty()
        && children.len() == 1
        && children[0].is_dir()
    {
        let src = &children[0];
        let target = dest.join(src.file_name().unwrap());
        if target.exists() {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&format!("Already exists: {}", target.display()));
        }
        if let Err(e) = move_path(src, &target) {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&e);
        }
        target
    } else if top_dirs.is_empty()
        && top_files.len() == 1
        && children.len() == 1
        && children[0].is_file()
    {
        let src = &children[0];
        let target = dest.join(src.file_name().unwrap());
        if target.exists() {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&format!("Already exists: {}", target.display()));
        }
        if let Err(e) = move_path(src, &target) {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&e);
        }
        target
    } else {
        let target = dest.join(&base);
        if target.exists() {
            let _ = fs::remove_dir_all(&tmp);
            err_exit(&format!("Already exists: {}", target.display()));
        }
        let _ = fs::create_dir_all(&target);
        for child in &children {
            let t = target.join(child.file_name().unwrap());
            if let Err(e) = move_path(child, &t) {
                let _ = fs::remove_dir_all(&tmp);
                err_exit(&e);
            }
        }
        target
    };

    let _ = fs::remove_dir_all(&tmp);
    progress(1.0, "Done");

    let mode = if top_dirs.len() == 1 && top_files.is_empty() {
        "single-root-folder"
    } else if top_files.len() == 1 && top_dirs.is_empty() {
        "single-file"
    } else {
        "wrapped-folder"
    };

    out_ok(serde_json::json!({
        "ok": true,
        "archive": archive.to_string_lossy(),
        "result": result.to_string_lossy(),
        "isDir": result.is_dir(),
        "mode": mode,
    }));
}

fn tempfile_dir() -> PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "donwaztok-fm-{}",
        std::process::id()
    ));
    let _ = fs::create_dir_all(&dir);
    // unique
    let dir = std::env::temp_dir().join(format!(
        "donwaztok-fm-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ));
    let _ = fs::create_dir_all(&dir);
    dir
}
