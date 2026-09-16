//! Entry metadata: MIME types, thumbnail flags, constants.

use std::collections::HashMap;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

pub static IMAGE_EXTS: &[&str] = &[
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".avif", ".jxl",
];
pub static THUMBNAIL_EXTS: &[&str] = &[
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".avif", ".jxl", ".ico",
];
pub static THUMBNAIL_CONVERT_EXTS: &[&str] = &[".webp", ".avif", ".jxl", ".ico"];
pub static PE_ICON_EXTS: &[&str] = &[".exe", ".dll"];
pub static LINUX_BIN_EXTS: &[&str] = &[".run", ".bin", ".elf"];
pub static ARCHIVE_EXTS: &[&str] = &[".zip", ".7z", ".7zip", ".rar", ".cbr"];
pub static SCRIPT_EXTS: &[&str] = &[
    ".sh", ".bash", ".zsh", ".fish", ".py", ".pyw", ".rb", ".pl", ".lua", ".js", ".mjs", ".ts",
    ".ps1", ".bat", ".cmd",
];

fn ext_mime(suffix: &str) -> Option<&'static str> {
    match suffix {
        ".appimage" | ".AppImage" => Some("application/vnd.appimage"),
        ".code-workspace" => Some("application/vnd.code.workspace"),
        ".desktop" => Some("application/x-desktop"),
        ".exe" | ".dll" => Some("application/x-msdownload"),
        ".msi" => Some("application/x-msi"),
        ".cs" => Some("text/x-csharp"),
        ".ts" | ".tsx" => Some("text/typescript"),
        ".jsx" => Some("text/jsx"),
        ".rs" => Some("text/rust"),
        ".go" => Some("text/x-go"),
        ".py" => Some("text/x-python"),
        ".json" => Some("application/json"),
        ".toml" => Some("application/toml"),
        ".yaml" | ".yml" => Some("text/yaml"),
        ".md" => Some("text/markdown"),
        ".pdf" => Some("application/pdf"),
        ".epub" => Some("application/epub+zip"),
        ".torrent" => Some("application/x-bittorrent"),
        ".iso" => Some("application/x-iso9660-image"),
        ".apk" => Some("application/vnd.android.package-archive"),
        ".deb" => Some("application/vnd.debian.binary-package"),
        ".rpm" => Some("application/x-rpm"),
        ".csv" => Some("text/csv"),
        ".svg" => Some("image/svg+xml"),
        ".run" => Some("application/x-makeself"),
        ".rar" | ".cbr" => Some("application/vnd.rar"),
        _ => None,
    }
}

pub fn suffix_lower(path: &Path) -> String {
    path.extension()
        .map(|e| format!(".{}", e.to_string_lossy().to_lowercase()))
        .unwrap_or_default()
}

pub fn suffix_no_dot(path: &Path) -> String {
    path.extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default()
}

pub fn mime_for(path: &Path, is_dir: bool) -> String {
    if is_dir {
        return "inode/directory".into();
    }
    let name_l = path
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    if name_l.ends_with(".appimage") {
        return "application/vnd.appimage".into();
    }
    let suffix = suffix_lower(path);
    if let Some(m) = ext_mime(&suffix) {
        return m.into();
    }
    if let Some(g) = mime_guess::from_path(path).first() {
        return g.essence_str().to_string();
    }
    if ARCHIVE_EXTS.contains(&suffix.as_str()) {
        return if suffix == ".zip" {
            "application/zip".into()
        } else if suffix == ".rar" || suffix == ".cbr" {
            "application/vnd.rar".into()
        } else {
            "application/x-7z-compressed".into()
        };
    }
    "application/octet-stream".into()
}

pub fn is_executable(path: &Path, is_dir: bool) -> bool {
    if is_dir {
        return false;
    }
    match fs::metadata(path) {
        Ok(m) if m.is_file() => m.permissions().mode() & 0o111 != 0,
        _ => false,
    }
}

#[derive(Debug, Clone)]
pub struct EntryFlags {
    pub is_executable: bool,
    pub is_appimage: bool,
    pub is_desktop: bool,
    pub is_windows_exe: bool,
    pub is_linux_bin: bool,
    pub can_thumbnail: bool,
    pub thumb_kind: String,
}

pub fn entry_flags(path: &Path, is_dir: bool) -> EntryFlags {
    let name_l = path
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let executable = is_executable(path, is_dir);
    let suffix = suffix_lower(path);
    let is_appimage = !is_dir && name_l.ends_with(".appimage");
    let is_desktop = !is_dir && suffix == ".desktop";
    let is_windows_exe = !is_dir && PE_ICON_EXTS.contains(&suffix.as_str());
    let is_linux_bin = !is_dir
        && executable
        && !is_appimage
        && !is_windows_exe
        && !SCRIPT_EXTS.contains(&suffix.as_str())
        && (LINUX_BIN_EXTS.contains(&suffix.as_str()) || suffix.is_empty());

    let mut can_linux_thumb = false;
    if is_linux_bin {
        let idx = desktop_index_by_binary();
        let base = path
            .file_name()
            .map(|n| n.to_string_lossy().to_lowercase())
            .unwrap_or_default();
        let stem = path
            .file_stem()
            .map(|n| n.to_string_lossy().to_lowercase())
            .unwrap_or_default();
        can_linux_thumb = idx.contains_key(&base) || idx.contains_key(&stem);
    }

    let can_thumb = !is_dir
        && (THUMBNAIL_EXTS.contains(&suffix.as_str())
            || is_windows_exe
            || is_appimage
            || is_desktop
            || can_linux_thumb);

    let kind = if is_windows_exe {
        "exe"
    } else if is_appimage {
        "appimage"
    } else if is_desktop {
        "desktop"
    } else if can_linux_thumb {
        "linux"
    } else if THUMBNAIL_CONVERT_EXTS.contains(&suffix.as_str()) {
        "convert"
    } else if THUMBNAIL_EXTS.contains(&suffix.as_str()) {
        "image"
    } else {
        ""
    };

    EntryFlags {
        is_executable: executable,
        is_appimage,
        is_desktop,
        is_windows_exe,
        is_linux_bin,
        can_thumbnail: can_thumb,
        thumb_kind: kind.into(),
    }
}

fn applications_dirs() -> Vec<PathBuf> {
    let home = dirs_home();
    vec![
        home.join(".local/share/applications"),
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        home.join(".local/share/flatpak/exports/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
    ]
}

pub fn dirs_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/"))
}

pub fn parse_desktop_key(path: &Path, key: &str) -> Option<String> {
    let text = fs::read_to_string(path).ok()?;
    let mut in_entry = false;
    for line in text.lines() {
        let s = line.trim();
        if s.is_empty() || s.starts_with('#') {
            continue;
        }
        if s.starts_with('[') && s.ends_with(']') {
            in_entry = s == "[Desktop Entry]";
            continue;
        }
        if !in_entry || !s.contains('=') {
            continue;
        }
        let (k, v) = s.split_once('=')?;
        if k.trim() == key {
            return Some(v.trim().to_string());
        }
    }
    None
}

fn desktop_index_by_binary() -> &'static HashMap<String, PathBuf> {
    static INDEX: OnceLock<HashMap<String, PathBuf>> = OnceLock::new();
    INDEX.get_or_init(|| {
        let mut index: HashMap<String, PathBuf> = HashMap::new();
        for d in applications_dirs() {
            let Ok(rd) = fs::read_dir(&d) else {
                continue;
            };
            for ent in rd.flatten() {
                let path = ent.path();
                if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                    continue;
                }
                let icon = parse_desktop_key(&path, "Icon");
                let exec_line = parse_desktop_key(&path, "Exec").unwrap_or_default();
                let stem = path
                    .file_stem()
                    .map(|s| s.to_string_lossy().to_lowercase())
                    .unwrap_or_default();
                if icon.is_some() && !index.contains_key(&stem) {
                    index.insert(stem, path.clone());
                }
                if exec_line.is_empty() {
                    continue;
                }
                let cleaned: String = {
                    let mut out = String::new();
                    let chars: Vec<char> = exec_line.chars().collect();
                    let mut i = 0;
                    while i < chars.len() {
                        if chars[i] == '%' && i + 1 < chars.len() && chars[i + 1].is_ascii_alphabetic()
                        {
                            i += 2;
                            continue;
                        }
                        out.push(chars[i]);
                        i += 1;
                    }
                    out.trim().to_string()
                };
                if cleaned.is_empty() {
                    continue;
                }
                let mut bin_tok = None;
                for tok in cleaned.split_whitespace() {
                    if tok.starts_with('-') {
                        continue;
                    }
                    if tok.contains('=') && !tok.starts_with('/') {
                        continue;
                    }
                    bin_tok = Some(tok);
                    break;
                }
                let Some(bin_tok) = bin_tok else {
                    continue;
                };
                let base = Path::new(bin_tok)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_lowercase())
                    .unwrap_or_default();
                if base.is_empty() {
                    continue;
                }
                if !index.contains_key(&base) {
                    index.insert(base.clone(), path.clone());
                }
                if icon.is_some() {
                    index.insert(base, path.clone());
                }
            }
        }
        index
    })
}

pub fn desktop_icon_search_roots() -> Vec<PathBuf> {
    let home = dirs_home();
    vec![
        home.join(".local/share/icons"),
        home.join(".icons"),
        PathBuf::from("/usr/share/icons"),
        PathBuf::from("/usr/local/share/icons"),
        PathBuf::from("/usr/share/pixmaps"),
        PathBuf::from("/usr/local/share/pixmaps"),
    ]
}

pub fn resolve_icon_name(name: &str, prefer_px: u32) -> Option<PathBuf> {
    let raw = name.trim().trim_matches('"').trim_matches('\'').to_string();
    if raw.is_empty() {
        return None;
    }
    let p = crate::protocol::expand_user(&raw);
    if raw.starts_with('/') || raw.starts_with('~') {
        if p.is_file() {
            return Some(p);
        }
        for ext in [".png", ".svg", ".xpm", ".ico"] {
            let cand = PathBuf::from(format!("{}{}", p.display(), ext));
            if cand.is_file() {
                return Some(cand);
            }
        }
        return None;
    }

    let mut stem = raw.clone();
    let low = stem.to_lowercase();
    for ext in [".png", ".svg", ".xpm", ".ico"] {
        if low.ends_with(ext) {
            stem = Path::new(&stem)
                .file_stem()
                .map(|s| s.to_string_lossy().into_owned())
                .unwrap_or(stem);
            break;
        }
    }

    let mut sizes = vec![
        format!("{prefer_px}x{prefer_px}"),
        "scalable".into(),
        "512x512".into(),
        "256x256".into(),
        "128x128".into(),
        "64x64".into(),
        "48x48".into(),
        "32x32".into(),
        "24x24".into(),
        "22x22".into(),
        "16x16".into(),
    ];
    sizes.sort_by_key(|s| {
        if s == "scalable" {
            0i32
        } else if let Some((a, _)) = s.split_once('x') {
            a.parse::<i32>()
                .map(|n| (n - prefer_px as i32).abs())
                .unwrap_or(prefer_px as i32)
        } else {
            prefer_px as i32
        }
    });

    let themes = [
        "hicolor",
        "Adwaita",
        "breeze",
        "breeze-dark",
        "Papirus",
        "Papirus-Dark",
        "Tela",
        "Tela-dark",
        "WhiteSur",
        "WhiteSur-dark",
    ];
    let cats = [
        "apps", "places", "devices", "mimetypes", "actions", "status", "categories", "emblems",
    ];
    let exts = [".png", ".svg", ".xpm"];

    for root in desktop_icon_search_roots() {
        if !root.is_dir() {
            continue;
        }
        if root.file_name().and_then(|n| n.to_str()) == Some("pixmaps") {
            for ext in exts {
                let cand = root.join(format!("{stem}{ext}"));
                if cand.is_file() {
                    return Some(cand);
                }
            }
            continue;
        }
        for theme in themes {
            let td = root.join(theme);
            if !td.is_dir() {
                continue;
            }
            for sz in &sizes {
                for cat in cats {
                    for ext in exts {
                        let cand = td.join(sz).join(cat).join(format!("{stem}{ext}"));
                        if cand.is_file() {
                            return Some(cand);
                        }
                    }
                }
            }
        }
    }
    None
}

pub fn resolve_desktop_file_icon(desktop: &Path, prefer_px: u32) -> Option<PathBuf> {
    let icon = parse_desktop_key(desktop, "Icon")?;
    resolve_icon_name(&icon, prefer_px)
}

pub fn resolve_linux_bin_icon(exe: &Path, prefer_px: u32) -> Option<PathBuf> {
    let idx = desktop_index_by_binary();
    let name = exe
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let stem = exe
        .file_stem()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    if let Some(desk) = idx.get(&name).or_else(|| idx.get(&stem)) {
        return resolve_desktop_file_icon(desk, prefer_px);
    }
    resolve_icon_name(&stem, prefer_px).or_else(|| resolve_icon_name(&name, prefer_px))
}
