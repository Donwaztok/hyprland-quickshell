//! Compress selected paths into zip / 7z archives.

use crate::extract::{find_7z, path_size};
use crate::protocol::{err_exit, expand_user, out_ok, progress};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use walkdir::WalkDir;
use zip::write::SimpleFileOptions;
use zip::CompressionMethod;
use zip::ZipWriter;

fn archive_base_name(sources: &[PathBuf]) -> String {
    if sources.len() == 1 {
        let p = &sources[0];
        p.file_stem()
            .or_else(|| p.file_name())
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_else(|| "Archive".into())
    } else {
        "Archive".into()
    }
}

fn unique_archive_path(dest_dir: &Path, base: &str, ext: &str) -> PathBuf {
    let primary = dest_dir.join(format!("{base}{ext}"));
    if !primary.exists() {
        return primary;
    }
    for i in 2..10_000 {
        let cand = dest_dir.join(format!("{base} ({i}){ext}"));
        if !cand.exists() {
            return cand;
        }
    }
    dest_dir.join(format!("{base}-{}.{}", std::process::id(), &ext[1..]))
}

fn collect_files(sources: &[PathBuf]) -> Result<Vec<(PathBuf, String)>, String> {
    let mut out = Vec::new();
    for src in sources {
        if !src.exists() {
            return Err(format!("Missing: {}", src.display()));
        }
        let root_name = src
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "item".into());
        if src.is_file() {
            out.push((src.clone(), root_name));
            continue;
        }
        if src.is_dir() {
            for ent in WalkDir::new(src).follow_links(false).into_iter().flatten() {
                let p = ent.path();
                if !ent.file_type().is_file() {
                    continue;
                }
                let rel = p
                    .strip_prefix(src)
                    .map(|r| r.to_string_lossy().replace('\\', "/"))
                    .unwrap_or_default();
                if rel.is_empty() {
                    continue;
                }
                let archive_path = format!("{root_name}/{rel}");
                out.push((p.to_path_buf(), archive_path));
            }
            // Ensure empty dirs are represented? skip for zip simplicity
            continue;
        }
    }
    Ok(out)
}

fn compress_zip(sources: &[PathBuf], archive: &Path) -> Result<(), String> {
    let files = collect_files(sources)?;
    if files.is_empty() {
        // Empty folder(s) — still create a zip with directory entries
        let f = File::create(archive).map_err(|e| e.to_string())?;
        let mut zip = ZipWriter::new(f);
        for src in sources {
            if src.is_dir() {
                let name = src
                    .file_name()
                    .map(|n| format!("{}/", n.to_string_lossy()))
                    .unwrap_or_else(|| "folder/".into());
                zip.add_directory(name, SimpleFileOptions::default())
                    .map_err(|e| e.to_string())?;
            }
        }
        zip.finish().map_err(|e| e.to_string())?;
        return Ok(());
    }

    let total: u64 = files
        .iter()
        .map(|(p, _)| p.metadata().map(|m| m.len()).unwrap_or(0))
        .sum::<u64>()
        .max(1);
    let mut done = 0u64;

    let f = File::create(archive).map_err(|e| e.to_string())?;
    let mut zip = ZipWriter::new(f);
    let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);

    for (i, (path, name)) in files.iter().enumerate() {
        zip.start_file(name.replace('\\', "/"), opts)
            .map_err(|e| e.to_string())?;
        let mut input = File::open(path).map_err(|e| e.to_string())?;
        let mut buf = [0u8; 64 * 1024];
        loop {
            let n = input.read(&mut buf).map_err(|e| e.to_string())?;
            if n == 0 {
                break;
            }
            zip.write_all(&buf[..n]).map_err(|e| e.to_string())?;
            done += n as u64;
            let pct = (done as f64 / total as f64).min(0.95);
            progress(
                pct.max((i as f64 + 0.5) / files.len().max(1) as f64 * 0.95),
                &format!("Compressing {name}"),
            );
        }
    }
    zip.finish().map_err(|e| e.to_string())?;
    Ok(())
}

fn compress_7z(sources: &[PathBuf], archive: &Path) -> Result<(), String> {
    let seven = find_7z().ok_or_else(|| "7zip not found (install 7zip)".to_string())?;
    let total: u64 = sources.iter().map(|p| path_size(p)).sum::<u64>().max(1);

    let mut cmd = Command::new(&seven);
    cmd.arg("a")
        .arg("-t7z")
        .arg("-y")
        .arg(archive)
        .args(sources)
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    // Poll archive size for progress while 7z runs
    let mut child = cmd.spawn().map_err(|e| e.to_string())?;
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                if !status.success() {
                    let _ = fs::remove_file(archive);
                    return Err(format!("7z compress failed (exit {})", status));
                }
                break;
            }
            Ok(None) => {
                let cur = archive.metadata().map(|m| m.len()).unwrap_or(0);
                // Compressed size vs uncompressed is rough — cap at 0.9 until done
                let pct = ((cur as f64 / total as f64) * 0.5).min(0.9);
                progress(pct, "Compressing…");
                std::thread::sleep(std::time::Duration::from_millis(200));
            }
            Err(e) => {
                let _ = fs::remove_file(archive);
                return Err(e.to_string());
            }
        }
    }
    if !archive.is_file() {
        return Err("7z did not create archive".into());
    }
    Ok(())
}

/// Compress sources into dest_dir as zip or 7z.
pub fn smart_compress(dest_dir: &str, sources: &[String], format: &str) {
    if sources.is_empty() {
        err_exit("compress requires at least one path");
    }
    let dest = expand_user(dest_dir);
    let dest = dest.canonicalize().unwrap_or(dest);
    if !dest.is_dir() {
        err_exit(&format!("Destination is not a directory: {}", dest.display()));
    }

    let fmt = format.trim().to_lowercase();
    let (ext, use_7z) = match fmt.as_str() {
        "7z" | "7zip" => (".7z", true),
        "zip" | "" => (".zip", false),
        other => err_exit(&format!("Unsupported compress format: {other}")),
    };

    let paths: Vec<PathBuf> = sources.iter().map(|s| expand_user(s)).collect();
    for p in &paths {
        if !p.exists() {
            err_exit(&format!("Missing: {}", p.display()));
        }
        // Refuse compressing into a path that would nest inside a selected folder oddly —
        // archive always lands in dest_dir.
    }

    let base = archive_base_name(&paths);
    let archive = unique_archive_path(&dest, &base, ext);

    progress(0.02, "Preparing…");
    let result = if use_7z {
        compress_7z(&paths, &archive)
    } else {
        compress_zip(&paths, &archive)
    };

    if let Err(e) = result {
        let _ = fs::remove_file(&archive);
        err_exit(&e);
    }

    progress(1.0, "Done");
    out_ok(serde_json::json!({
        "ok": true,
        "result": archive.to_string_lossy(),
        "format": if use_7z { "7z" } else { "zip" },
        "count": paths.len(),
    }));
}
