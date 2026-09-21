#!/usr/bin/env python3
"""Donwaztok file manager helpers: list, mounts, ops, smart archive extract."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import grp
import json
import mimetypes
import os
import pwd
import re
import shutil
import stat as statmod
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zipfile
from pathlib import Path
from typing import Any


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".avif", ".jxl"}
# Base formats always OK for Qt Image; webp/avif/jxl/ico use magick thumb fallback in UI
THUMBNAIL_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".avif", ".jxl", ".ico"}
THUMBNAIL_CONVERT_EXTS = {".webp", ".avif", ".jxl", ".ico"}
PE_ICON_EXTS = {".exe", ".dll"}
LINUX_BIN_EXTS = {".run", ".bin", ".elf"}
ARCHIVE_EXTS = {".zip", ".7z", ".7zip", ".rar", ".cbr"}
SCRIPT_EXTS = {
    ".sh", ".bash", ".zsh", ".fish", ".py", ".pyw", ".rb", ".pl", ".lua",
    ".js", ".mjs", ".ts", ".ps1", ".bat", ".cmd",
}
EXT_MIME = {
    ".appimage": "application/vnd.appimage",
    ".code-workspace": "application/vnd.code.workspace",
    ".desktop": "application/x-desktop",
    ".AppImage": "application/vnd.appimage",
    ".exe": "application/x-msdownload",
    ".dll": "application/x-msdownload",
    ".msi": "application/x-msi",
    ".cs": "text/x-csharp",
    ".ts": "text/typescript",
    ".tsx": "text/typescript",
    ".jsx": "text/jsx",
    ".rs": "text/rust",
    ".go": "text/x-go",
    ".py": "text/x-python",
    ".json": "application/json",
    ".toml": "application/toml",
    ".yaml": "text/yaml",
    ".yml": "text/yaml",
    ".md": "text/markdown",
    ".pdf": "application/pdf",
    ".epub": "application/epub+zip",
    ".torrent": "application/x-bittorrent",
    ".iso": "application/x-iso9660-image",
    ".apk": "application/vnd.android.package-archive",
    ".deb": "application/vnd.debian.binary-package",
    ".rpm": "application/x-rpm",
    ".csv": "text/csv",
    ".svg": "image/svg+xml",
    ".run": "application/x-makeself",
}


def emit(obj: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def progress(pct: float, message: str = "") -> None:
    emit({"type": "progress", "progress": max(0.0, min(1.0, float(pct))), "message": message})


def out(data: Any) -> None:
    # Final result — keep backward compatible keys and mark as done.
    if isinstance(data, dict):
        payload = dict(data)
        payload.setdefault("type", "done" if payload.get("ok", True) else "error")
        emit(payload)
    else:
        emit({"type": "done", "ok": True, "data": data})


def err(msg: str, code: int = 1) -> None:
    emit({"type": "error", "ok": False, "error": msg})
    raise SystemExit(code)


def human_path(p: Path) -> str:
    return str(p.expanduser().resolve())


def mime_for(path: Path, is_dir: bool) -> str:
    if is_dir:
        return "inode/directory"
    # Explicit map — Python mimetypes misses AppImage / workspaces
    lower_name = path.name.lower()
    if lower_name.endswith(".appimage"):
        return "application/vnd.appimage"
    suffix = path.suffix.lower()
    if suffix in EXT_MIME:
        return EXT_MIME[suffix]
    guessed, _ = mimetypes.guess_type(str(path))
    if guessed:
        return guessed
    if suffix in ARCHIVE_EXTS:
        return "application/zip" if suffix == ".zip" else "application/x-7z-compressed"
    return "application/octet-stream"


def entry_flags(path: Path, is_dir: bool) -> dict[str, Any]:
    name_l = path.name.lower()
    executable = (not is_dir) and path.is_file() and os.access(path, os.X_OK)
    suffix = path.suffix.lower()
    is_appimage = (not is_dir) and name_l.endswith(".appimage")
    is_desktop = (not is_dir) and suffix == ".desktop"
    is_windows_exe = (not is_dir) and suffix in PE_ICON_EXTS
    # ELF / .run — only thumbnail when a .desktop (or theme icon) maps to this name
    is_linux_bin = (
        (not is_dir)
        and executable
        and not is_appimage
        and not is_windows_exe
        and suffix not in SCRIPT_EXTS
        and (suffix in LINUX_BIN_EXTS or suffix == "")
    )
    can_linux_thumb = False
    if is_linux_bin:
        idx = _desktop_index_by_binary()
        can_linux_thumb = path.name.lower() in idx or path.stem.lower() in idx
    can_thumb = (not is_dir) and (
        suffix in THUMBNAIL_EXTS
        or is_windows_exe
        or is_appimage
        or is_desktop
        or can_linux_thumb
    )
    if is_windows_exe:
        kind = "exe"
    elif is_appimage:
        kind = "appimage"
    elif is_desktop:
        kind = "desktop"
    elif can_linux_thumb:
        kind = "linux"
    elif suffix in THUMBNAIL_CONVERT_EXTS:
        kind = "convert"
    elif suffix in THUMBNAIL_EXTS:
        kind = "image"
    else:
        kind = ""
    return {
        "isExecutable": bool(executable),
        "isAppImage": is_appimage,
        "isDesktop": is_desktop,
        "isWindowsExe": is_windows_exe,
        "isLinuxBin": bool(is_linux_bin),
        "canThumbnail": bool(can_thumb),
        "thumbKind": kind,
    }


def _magick_resize(src: Path, dest: Path, px: int) -> None:
    code, msg = _run_cmd(["magick", str(src), "-resize", f"{px}x{px}", str(dest)])
    if code != 0 or not dest.is_file():
        err(msg or "magick failed converting icon")


def _desktop_icon_search_roots() -> list[Path]:
    home = Path.home()
    return [
        home / ".local/share/icons",
        home / ".icons",
        Path("/usr/share/icons"),
        Path("/usr/local/share/icons"),
        Path("/usr/share/pixmaps"),
        Path("/usr/local/share/pixmaps"),
    ]


def resolve_icon_name(name: str, prefer_px: int = 64) -> Path | None:
    """Resolve a freedesktop Icon= value (name or absolute path) to a file."""
    raw = (name or "").strip().strip('"').strip("'")
    if not raw:
        return None
    p = Path(raw).expanduser()
    if raw.startswith("/") or raw.startswith("~"):
        if p.is_file():
            return p
        for ext in (".png", ".svg", ".xpm", ".ico"):
            cand = Path(str(p) + ext)
            if cand.is_file():
                return cand
        return None

    stem = raw
    if stem.lower().endswith((".png", ".svg", ".xpm", ".ico")):
        stem = Path(stem).stem

    sizes = [
        f"{prefer_px}x{prefer_px}",
        "scalable",
        "512x512",
        "256x256",
        "128x128",
        "64x64",
        "48x48",
        "32x32",
        "24x24",
        "22x22",
        "16x16",
    ]
    # Prefer sizes closest to prefer_px first
    sizes = sorted(
        set(sizes),
        key=lambda s: (
            0 if s == "scalable" else abs((int(s.split("x")[0]) if "x" in s else prefer_px) - prefer_px),
            s,
        ),
    )
    themes = [
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
    ]
    cats = ["apps", "places", "devices", "mimetypes", "actions", "status", "categories", "emblems"]
    exts = [".png", ".svg", ".xpm"]

    for root in _desktop_icon_search_roots():
        if not root.is_dir():
            continue
        if root.name == "pixmaps":
            for ext in exts:
                cand = root / f"{stem}{ext}"
                if cand.is_file():
                    return cand
            continue
        for theme in themes:
            td = root / theme
            if not td.is_dir():
                continue
            for sz in sizes:
                for cat in cats:
                    for ext in exts:
                        cand = td / sz / cat / f"{stem}{ext}"
                        if cand.is_file():
                            return cand
    return None


def parse_desktop_key(path: Path, key: str = "Icon") -> str | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    in_entry = False
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("[") and s.endswith("]"):
            in_entry = s == "[Desktop Entry]"
            continue
        if not in_entry or "=" not in s:
            continue
        k, _, v = s.partition("=")
        if k.strip() == key:
            return v.strip()
    return None


def _applications_dirs() -> list[Path]:
    home = Path.home()
    return [
        home / ".local/share/applications",
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
        home / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"),
    ]


_desktop_bin_index: dict[str, Path] | None = None


def _desktop_index_by_binary() -> dict[str, Path]:
    """Map executable basename → .desktop path (best-effort, cached)."""
    global _desktop_bin_index
    if _desktop_bin_index is not None:
        return _desktop_bin_index
    index: dict[str, Path] = {}
    for d in _applications_dirs():
        if not d.is_dir():
            continue
        try:
            desks = list(d.glob("*.desktop"))
        except OSError:
            continue
        for desk in desks:
            icon = parse_desktop_key(desk, "Icon")
            exec_line = parse_desktop_key(desk, "Exec") or ""
            # Also index by desktop file stem / Icon name
            if icon and desk.stem not in index:
                index[desk.stem.lower()] = desk
            if not exec_line:
                continue
            # Strip field codes and split
            cleaned = re.sub(r"%[a-zA-Z]", "", exec_line).strip()
            if not cleaned:
                continue
            # env FOO=bar cmd → take last token that looks like a path/name
            parts = cleaned.split()
            bin_tok = None
            for tok in parts:
                if tok.startswith("-"):
                    continue
                if "=" in tok and not tok.startswith("/"):
                    continue
                bin_tok = tok
                break
            if not bin_tok:
                continue
            base = Path(bin_tok).name.lower()
            if base and base not in index:
                index[base] = desk
            # Prefer entries that have an Icon
            if base and icon:
                index[base] = desk
    _desktop_bin_index = index
    return index


def resolve_desktop_file_icon(desktop: Path, prefer_px: int = 64) -> Path | None:
    icon = parse_desktop_key(desktop, "Icon")
    if not icon:
        return None
    return resolve_icon_name(icon, prefer_px=prefer_px)


def resolve_linux_bin_icon(exe: Path, prefer_px: int = 64) -> Path | None:
    idx = _desktop_index_by_binary()
    desk = idx.get(exe.name.lower()) or idx.get(exe.stem.lower())
    if not desk:
        # Try icon name == binary name directly
        return resolve_icon_name(exe.stem, prefer_px=prefer_px) or resolve_icon_name(exe.name, prefer_px=prefer_px)
    return resolve_desktop_file_icon(desk, prefer_px=prefer_px)


def _appimage_list_paths(ai: Path) -> list[str]:
    try:
        proc = subprocess.run(
            ["7z", "l", "-ba", str(ai)],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=90,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    paths: list[str] = []
    for line in (proc.stdout or "").splitlines():
        parts = line.split()
        if not parts:
            continue
        name = parts[-1]
        low = name.lower()
        if low.endswith((".png", ".svg", ".xpm", ".ico")) or name.endswith(".DirIcon") or low.endswith("/.diricon"):
            paths.append(name)
    return paths


def _score_appimage_icon_path(name: str) -> int:
    low = name.lower()
    score = 0
    m = re.search(r"/(\d+)x\d+/", low)
    if m:
        score += int(m.group(1))
    if "/apps/" in low:
        score += 10000
    if low.endswith(".png"):
        score += 80
    elif low.endswith(".svg"):
        score += 60
    if name.endswith(".DirIcon") or low.endswith("/.diricon"):
        score += 3000
    if "/" not in name and low.endswith((".png", ".svg")):
        score += 1500
    return score


def extract_appimage_icon_file(ai: Path) -> Path | None:
    """Extract the best embedded AppImage icon to a temp file; caller deletes it."""
    candidates = _appimage_list_paths(ai)
    if not candidates:
        return None
    ordered = sorted(candidates, key=_score_appimage_icon_path, reverse=True)
    tmp = Path(tempfile.mkdtemp(prefix="fm-appimage-"))
    try:
        for rel in ordered[:12]:
            try:
                proc = subprocess.run(
                    ["7z", "e", "-y", f"-o{tmp}", str(ai), rel],
                    capture_output=True,
                    text=True,
                    errors="replace",
                    timeout=90,
                )
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue
            # 7z may warn but still extract
            files = [p for p in tmp.rglob("*") if p.is_file() and not p.is_symlink()]
            # Resolve symlink .DirIcon by extracting target next
            for p in list(tmp.iterdir()):
                if p.is_symlink():
                    target = os.readlink(p)
                    if target:
                        subprocess.run(
                            ["7z", "e", "-y", f"-o{tmp}", str(ai), target],
                            capture_output=True,
                            timeout=90,
                        )
                        files = [f for f in tmp.rglob("*") if f.is_file() and not f.is_symlink()]
            pngs = [f for f in files if f.suffix.lower() in {".png", ".svg", ".xpm", ".ico"}]
            if not pngs:
                # clear for next attempt
                for f in tmp.iterdir():
                    try:
                        if f.is_dir():
                            shutil.rmtree(f, ignore_errors=True)
                        else:
                            f.unlink(missing_ok=True)
                    except OSError:
                        pass
                continue
            # Prefer largest file (usually highest-res PNG)
            best = max(pngs, key=lambda f: f.stat().st_size)
            out = tmp / f"icon{best.suffix.lower()}"
            if best != out:
                shutil.copy2(best, out)
            return out
    except Exception:
        shutil.rmtree(tmp, ignore_errors=True)
        return None
    shutil.rmtree(tmp, ignore_errors=True)
    return None


def _pe_rva_to_off(sections: list[tuple[int, int, int]], rva: int) -> int | None:
    for vrva, span, rawptr in sections:
        if vrva <= rva < vrva + span:
            return rawptr + (rva - vrva)
    return None


def _pe_parse_resource_dir(data: bytes, sections: list[tuple[int, int, int]], res_rva: int, dir_rva: int) -> list[tuple[int, int]]:
    off = _pe_rva_to_off(sections, dir_rva)
    if off is None or off + 16 > len(data):
        return []
    named = struct.unpack_from("<H", data, off + 12)[0]
    ids = struct.unpack_from("<H", data, off + 14)[0]
    entries = []
    base = off + 16
    for i in range(named + ids):
        e = base + i * 8
        if e + 8 > len(data):
            break
        name_or_id, offset = struct.unpack_from("<II", data, e)
        entries.append((name_or_id, offset))
    return entries


def extract_pe_icon_bytes(exe_path: Path) -> bytes | None:
    """Return ICO file bytes for the largest icon embedded in a PE (.exe/.dll)."""
    try:
        data = exe_path.read_bytes()
    except OSError:
        return None
    if len(data) < 0x40 or data[:2] != b"MZ":
        return None
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if e_lfanew + 24 > len(data) or data[e_lfanew : e_lfanew + 4] != b"PE\0\0":
        return None
    coff = e_lfanew + 4
    num_sections = struct.unpack_from("<H", data, coff + 2)[0]
    opt_size = struct.unpack_from("<H", data, coff + 16)[0]
    opt = coff + 20
    if opt + 2 > len(data):
        return None
    magic = struct.unpack_from("<H", data, opt)[0]
    dd_off = opt + (112 if magic == 0x20B else 96)
    if dd_off + 24 > len(data):
        return None
    res_rva = struct.unpack_from("<I", data, dd_off + 16)[0]
    if not res_rva:
        return None
    sec_off = opt + opt_size
    sections: list[tuple[int, int, int]] = []
    for i in range(num_sections):
        o = sec_off + i * 40
        if o + 40 > len(data):
            break
        vsize = struct.unpack_from("<I", data, o + 8)[0]
        vrva = struct.unpack_from("<I", data, o + 12)[0]
        rawsize = struct.unpack_from("<I", data, o + 16)[0]
        rawptr = struct.unpack_from("<I", data, o + 20)[0]
        sections.append((vrva, max(vsize, rawsize), rawptr))

    RT_ICON = 3
    RT_GROUP_ICON = 14

    def walk(dir_rva: int) -> list[tuple[int, int]]:
        return _pe_parse_resource_dir(data, sections, res_rva, dir_rva)

    def is_subdir(offset_field: int) -> bool:
        return bool(offset_field & 0x80000000)

    def child_rva(offset_field: int) -> int:
        return res_rva + (offset_field & 0x7FFFFFFF)

    icon_blobs: dict[int, bytes] = {}
    groups: list[bytes] = []

    for tid, toff in walk(res_rva):
        type_id = tid & 0xFFFF
        if not is_subdir(toff):
            continue
        for nid, noff in walk(child_rva(toff)):
            if not is_subdir(noff):
                continue
            for _lid, loff in walk(child_rva(noff)):
                if is_subdir(loff):
                    continue
                entry_off = _pe_rva_to_off(sections, child_rva(loff))
                if entry_off is None or entry_off + 8 > len(data):
                    continue
                data_rva, size = struct.unpack_from("<II", data, entry_off)
                file_off = _pe_rva_to_off(sections, data_rva)
                if file_off is None or file_off + size > len(data):
                    continue
                blob = data[file_off : file_off + size]
                if type_id == RT_GROUP_ICON:
                    groups.append(blob)
                elif type_id == RT_ICON:
                    icon_blobs[nid & 0xFFFF] = blob

    if not icon_blobs:
        return None

    best_id = None
    best_score = -1
    best_wh = (32, 32)
    for gblob in groups:
        if len(gblob) < 6:
            continue
        count = struct.unpack_from("<H", gblob, 4)[0]
        for i in range(count):
            o = 6 + i * 14
            if o + 14 > len(gblob):
                break
            w, h, _c, _r, _planes, bpp, _nbytes, icon_id = struct.unpack_from("<BBBBHHIH", gblob, o)
            w = w or 256
            h = h or 256
            score = w * h * max(1, bpp or 32)
            if score > best_score and icon_id in icon_blobs:
                best_score = score
                best_id = icon_id
                best_wh = (w, h)

    if best_id is None:
        best_id = next(iter(icon_blobs))
        best_wh = (32, 32)

    img = icon_blobs[best_id]
    w, h = best_wh
    ico = bytearray()
    ico += struct.pack("<HHH", 0, 1, 1)
    ico += struct.pack(
        "<BBBBHHII",
        0 if w >= 256 else w,
        0 if h >= 256 else h,
        0,
        0,
        1,
        32,
        len(img),
        22,
    )
    ico += img
    return bytes(ico)


def do_thumb(path: str, dest: str, size: int = 64) -> None:
    src = Path(path).expanduser()
    out_path = Path(dest).expanduser()
    if not src.is_file():
        err(f"Not a file: {path}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    px = max(16, min(256, int(size) or 64))
    suffix = src.suffix.lower()
    name_l = src.name.lower()

    def finish_from_image(img: Path, kind: str) -> None:
        if img.suffix.lower() in {".png", ".jpg", ".jpeg", ".bmp", ".gif"} and img != out_path:
            _magick_resize(img, out_path, px)
        elif img.suffix.lower() == ".svg":
            _magick_resize(img, out_path, px)
        else:
            _magick_resize(img, out_path, px)
        out({"ok": True, "path": str(out_path), "kind": kind})

    if suffix in PE_ICON_EXTS:
        ico = extract_pe_icon_bytes(src)
        if not ico:
            err("No icon resource in executable")
        with tempfile.NamedTemporaryFile(suffix=".ico", delete=False) as tmp:
            tmp.write(ico)
            tmp_ico = tmp.name
        try:
            _magick_resize(Path(tmp_ico), out_path, px)
        finally:
            try:
                os.unlink(tmp_ico)
            except OSError:
                pass
        out({"ok": True, "path": str(out_path), "kind": "exe"})
        return

    if name_l.endswith(".appimage"):
        extracted = extract_appimage_icon_file(src)
        if not extracted:
            err("No icon found in AppImage")
        tmp_root = extracted.parent
        try:
            finish_from_image(extracted, "appimage")
        finally:
            shutil.rmtree(tmp_root, ignore_errors=True)
        return

    if suffix == ".desktop":
        icon_path = resolve_desktop_file_icon(src, prefer_px=px)
        if not icon_path:
            err("No Icon= in desktop file / theme")
        finish_from_image(icon_path, "desktop")
        return

    # Linux binary: map via .desktop Exec/Icon
    if os.access(src, os.X_OK) and suffix not in SCRIPT_EXTS and suffix not in THUMBNAIL_EXTS:
        icon_path = resolve_linux_bin_icon(src, prefer_px=px)
        if icon_path:
            finish_from_image(icon_path, "linux")
            return

    if suffix == ".ico" or suffix in THUMBNAIL_CONVERT_EXTS:
        _magick_resize(src, out_path, px)
        out({"ok": True, "path": str(out_path), "kind": "image"})
        return

    err(f"Unsupported thumb type: {suffix or src.name}")


def do_open(path: str) -> None:
    """Open a file like a desktop file manager (gio / exec AppImages)."""
    p = Path(path).expanduser()
    try:
        p = p.resolve(strict=False)
    except OSError:
        pass
    if not p.exists():
        err(f"Not found: {path}")
    if p.is_dir():
        err("Refusing to open a directory via open")

    name_l = p.name.lower()
    executable = p.is_file() and os.access(p, os.X_OK)

    # AppImages often have no default handler — run them directly (Nautilus “Run”).
    if name_l.endswith(".appimage"):
        if not executable:
            try:
                p.chmod(p.stat().st_mode | 0o111)
            except OSError as e:
                err(f"AppImage is not executable: {e}")
        subprocess.Popen(
            [str(p)],
            cwd=str(p.parent),
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        out({"ok": True, "mode": "exec", "path": str(p)})
        return

    # gio uses shared-mime + user defaults (e.g. .code-workspace → Cursor)
    code, msg = _run_cmd(["gio", "open", str(p)])
    if code == 0:
        out({"ok": True, "mode": "gio", "path": str(p)})
        return

    code2, msg2 = _run_cmd(["xdg-open", str(p)])
    if code2 == 0:
        out({"ok": True, "mode": "xdg-open", "path": str(p)})
        return

    if executable:
        subprocess.Popen(
            [str(p)],
            cwd=str(p.parent),
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        out({"ok": True, "mode": "exec-fallback", "path": str(p)})
        return

    err(msg or msg2 or f"No application found for {p.name}")


def _user_name(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)


def _group_name(gid: int) -> str:
    try:
        return grp.getgrgid(gid).gr_name
    except KeyError:
        return str(gid)


def _walk_usage(path: Path) -> dict[str, int]:
    file_count = 0
    dir_count = 0
    total = 0
    for root, dirnames, filenames in os.walk(path, followlinks=False):
        dir_count += len(dirnames)
        file_count += len(filenames)
        for name in filenames:
            try:
                total += os.lstat(os.path.join(root, name)).st_size
            except OSError:
                pass
    return {"size": int(total), "fileCount": file_count, "dirCount": dir_count}


def _trash_original(path: Path) -> str:
    try:
        files_dir = trash_root() / "files"
        if path.parent.resolve() != files_dir.resolve():
            return ""
        info = parse_trashinfo(trash_root() / "info" / f"{path.name}.trashinfo")
        return info.get("original") or ""
    except OSError:
        return ""


def _is_trash_uri(path: str) -> bool:
    return path in ("trash://", "trash:/", "trash:") or path.startswith("trash://")


def path_info(raw: str) -> dict[str, Any]:
    if _is_trash_uri(raw):
        usage = {"size": 0, "fileCount": 0, "dirCount": 0}
        try:
            files_dir = trash_root() / "files"
            if files_dir.is_dir():
                usage = _walk_usage(files_dir)
        except OSError:
            pass
        return {
            "name": "Trash",
            "path": "trash://",
            "parent": "",
            "isDir": True,
            "isFile": False,
            "isSymlink": False,
            "linkTarget": "",
            "originalPath": "",
            "mimeType": "inode/directory",
            "suffix": "",
            "size": usage["size"],
            "fileCount": usage["fileCount"],
            "dirCount": usage["dirCount"],
            "mtime": 0,
            "atime": 0,
            "ctime": 0,
            "mode": "",
            "modeOctal": "",
            "owner": "",
            "group": "",
            "exists": True,
        }

    p = Path(raw).expanduser()
    st = p.lstat()
    is_link = p.is_symlink()
    is_dir = False
    if is_link:
        try:
            is_dir = p.resolve().is_dir()
        except OSError:
            is_dir = False
    else:
        is_dir = p.is_dir()

    target = ""
    if is_link:
        try:
            target = os.readlink(p)
        except OSError:
            pass

    if is_dir:
        usage = _walk_usage(p)
        size = usage["size"]
        file_count = usage["fileCount"]
        dir_count = usage["dirCount"]
    else:
        size = int(st.st_size)
        file_count = 1
        dir_count = 0

    mode = st.st_mode
    return {
        "name": p.name or str(p),
        "path": str(p),
        "parent": str(p.parent),
        "isDir": is_dir,
        "isFile": (not is_dir) and p.is_file(),
        "isSymlink": is_link,
        "linkTarget": target,
        "originalPath": _trash_original(p),
        "mimeType": mime_for(p, is_dir),
        "suffix": p.suffix.lstrip(".").lower(),
        "size": size,
        "fileCount": file_count,
        "dirCount": dir_count,
        "mtime": int(st.st_mtime),
        "atime": int(st.st_atime),
        "ctime": int(st.st_ctime),
        "mode": statmod.filemode(mode),
        "modeOctal": f"{statmod.S_IMODE(mode):03o}",
        "owner": _user_name(st.st_uid),
        "group": _group_name(st.st_gid),
        "exists": True,
    }


def do_info(paths: list[str]) -> None:
    items: list[dict[str, Any]] = []
    for raw in paths:
        try:
            items.append(path_info(raw))
        except OSError as e:
            name = Path(raw).name or raw
            items.append(
                {
                    "name": name,
                    "path": raw,
                    "parent": str(Path(raw).parent) if raw else "",
                    "isDir": False,
                    "isFile": False,
                    "isSymlink": False,
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
                    "exists": False,
                    "error": str(e),
                }
            )

    out(
        {
            "ok": True,
            "count": len(items),
            "items": items,
            "totalSize": sum(int(i.get("size") or 0) for i in items),
            "selectedFiles": sum(1 for i in items if not i.get("isDir")),
            "selectedDirs": sum(1 for i in items if i.get("isDir")),
            "childFiles": sum(int(i.get("fileCount") or 0) for i in items),
            "childDirs": sum(int(i.get("dirCount") or 0) for i in items),
        }
    )


def xdg_dirs() -> None:
    """Resolve Places from XDG + common EN/PT folder names; skip dirs that resolve to $HOME."""
    home = Path.home()
    # (key, xdg-user-dir name or None, icon, candidate folder names under $HOME)
    specs: list[tuple[str, str | None, str, list[str]]] = [
        ("home", None, "home", []),
        (
            "downloads",
            "DOWNLOAD",
            "download",
            ["Downloads", "Download", "Baixados", "Transferências", "Transferencias"],
        ),
        (
            "desktop",
            "DESKTOP",
            "desktop_windows",
            ["Desktop", "Área de trabalho", "Area de trabalho", "Área de Trabalho", "Escritorio", "Escritório"],
        ),
        (
            "documents",
            "DOCUMENTS",
            "description",
            ["Documents", "Documentos", "Docs"],
        ),
        (
            "music",
            "MUSIC",
            "music_note",
            ["Music", "Músicas", "Musicas", "Música", "Musica"],
        ),
        (
            "pictures",
            "PICTURES",
            "image",
            ["Pictures", "Imagens", "Images", "Fotos", "Photos"],
        ),
        (
            "videos",
            "VIDEOS",
            "movie",
            ["Videos", "Vídeos", "Video", "Vídeo", "Movies", "Filmes"],
        ),
    ]

    result: dict[str, Any] = {"ok": True, "home": str(home)}
    places: list[dict[str, Any]] = []

    def add_unique(paths: list[Path], path: Path) -> None:
        try:
            if not path.is_dir():
                return
            resolved = str(path.resolve())
            if resolved == str(home.resolve()):
                # XDG dirs disabled with "$HOME/" must not appear as extra Places.
                return
        except OSError:
            return
        for existing in paths:
            try:
                if str(existing.resolve()) == resolved:
                    return
            except OSError:
                continue
        paths.append(path)

    for key, xdg, icon, names in specs:
        found: list[Path] = []

        if key == "home":
            found = [home]
            result["home"] = str(home)
            result["homeExists"] = True
        else:
            if xdg:
                try:
                    xdg_path = subprocess.check_output(["xdg-user-dir", xdg], text=True).strip()
                except (subprocess.CalledProcessError, FileNotFoundError):
                    xdg_path = ""
                if xdg_path:
                    add_unique(found, Path(xdg_path))

            for name in names:
                add_unique(found, home / name)

            # Prefer English folder names when several exist
            if names:
                def _rank(p: Path) -> int:
                    try:
                        return names.index(p.name)
                    except ValueError:
                        return len(names) + 1

                found.sort(key=_rank)

            preferred = found[0] if found else home / (names[0] if names else key.capitalize())
            result[key] = str(preferred)
            result[f"{key}Exists"] = len(found) > 0

        for path in found:
            label = "Home" if key == "home" else path.name
            places.append(
                {
                    "key": key,
                    "label": label,
                    "path": str(path),
                    "icon": icon,
                }
            )

    places.append({"key": "trash", "label": "Trash", "path": "trash://", "icon": "delete"})
    result["trash"] = "trash://"
    result["places"] = places
    out(result)


def trash_root() -> Path:
    data = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
    return Path(data) / "Trash"


def parse_trashinfo(info_path: Path) -> dict[str, str]:
    original = ""
    deleted = ""
    try:
        for line in info_path.read_text(errors="replace").splitlines():
            if line.startswith("Path="):
                original = line[5:]
                # Path may be percent-encoded
                try:
                    from urllib.parse import unquote

                    original = unquote(original)
                except Exception:
                    pass
            elif line.startswith("DeletionDate="):
                deleted = line[13:]
    except OSError:
        pass
    return {"original": original, "deleted": deleted}


def list_trash() -> None:
    root = trash_root()
    files_dir = root / "files"
    info_dir = root / "info"
    entries: list[dict[str, Any]] = []
    if not files_dir.is_dir():
        out({"ok": True, "path": "trash://", "entries": [], "isTrash": True})
        return

    try:
        children = list(files_dir.iterdir())
    except PermissionError:
        err("Permission denied: Trash")

    for child in children:
        name = child.name
        info = parse_trashinfo(info_dir / f"{name}.trashinfo")
        try:
            st = child.lstat()
            is_dir = child.is_dir() and not child.is_symlink()
            if child.is_symlink():
                try:
                    is_dir = child.resolve().is_dir()
                except OSError:
                    is_dir = False
            size = 0 if is_dir else int(st.st_size)
            mime = mime_for(child, is_dir)
            flags = entry_flags(child, is_dir)
            entries.append(
                {
                    "name": name,
                    "path": str(child),
                    "trashUri": f"trash:///{name}",
                    "originalPath": info.get("original") or "",
                    "isDir": is_dir,
                    "isSymlink": child.is_symlink(),
                    "isTrash": True,
                    "size": size,
                    "mtime": int(st.st_mtime),
                    "mimeType": mime,
                    "suffix": child.suffix.lstrip(".").lower(),
                    "isImage": (not is_dir) and child.suffix.lower() in IMAGE_EXTS,
                    "canThumbnail": flags["canThumbnail"],
                    "thumbKind": flags["thumbKind"],
                    "isArchive": False,
                    "isWindowsExe": flags["isWindowsExe"],
                    "isDesktop": flags["isDesktop"],
                    "isLinuxBin": flags["isLinuxBin"],
                }
            )
        except OSError:
            continue

    entries.sort(key=lambda e: (not e["isDir"], e["name"].casefold()))
    out({"ok": True, "path": "trash://", "entries": entries, "isTrash": True})


def list_dir(path: str, show_hidden: bool) -> None:
    if path in ("trash://", "trash:/", "trash:") or path.startswith("trash://"):
        list_trash()
        return

    root = Path(path).expanduser()
    if not root.is_dir():
        err(f"Not a directory: {path}")
    entries: list[dict[str, Any]] = []
    try:
        children = list(root.iterdir())
    except PermissionError:
        err(f"Permission denied: {path}")

    for child in children:
        name = child.name
        if not show_hidden and name.startswith("."):
            continue
        try:
            st = child.lstat()
            is_dir = child.is_dir() and not child.is_symlink()
            if child.is_symlink():
                try:
                    is_dir = child.resolve().is_dir()
                except OSError:
                    is_dir = False
            size = 0 if is_dir else int(st.st_size)
            mime = mime_for(child, is_dir)
            flags = entry_flags(child, is_dir)
            entries.append(
                {
                    "name": name,
                    "path": str(child),
                    "isDir": is_dir,
                    "isSymlink": child.is_symlink(),
                    "isTrash": False,
                    "size": size,
                    "mtime": int(st.st_mtime),
                    "mimeType": mime,
                    "suffix": child.suffix.lstrip(".").lower(),
                    "isImage": (not is_dir) and child.suffix.lower() in IMAGE_EXTS,
                    "canThumbnail": flags["canThumbnail"],
                    "thumbKind": flags["thumbKind"],
                    "isArchive": (not is_dir) and child.suffix.lower() in ARCHIVE_EXTS,
                    "isExecutable": flags["isExecutable"],
                    "isAppImage": flags["isAppImage"],
                    "isWindowsExe": flags["isWindowsExe"],
                    "isDesktop": flags["isDesktop"],
                    "isLinuxBin": flags["isLinuxBin"],
                }
            )
        except OSError:
            continue

    entries.sort(key=lambda e: (not e["isDir"], e["name"].casefold()))
    out({"ok": True, "path": str(root.resolve()), "entries": entries, "isTrash": False})


# linux/inotify.h
_IN_CLOEXEC = 0x80000
_IN_ATTRIB = 0x00000004
_IN_CLOSE_WRITE = 0x00000008
_IN_MOVED_FROM = 0x00000040
_IN_MOVED_TO = 0x00000080
_IN_CREATE = 0x00000100
_IN_DELETE = 0x00000200
_IN_DELETE_SELF = 0x00000400
_IN_MOVE_SELF = 0x00000800
_IN_ONLYDIR = 0x01000000
_IN_DIR_EVENTS = (
    _IN_ATTRIB
    | _IN_CLOSE_WRITE
    | _IN_MOVED_FROM
    | _IN_MOVED_TO
    | _IN_CREATE
    | _IN_DELETE
    | _IN_DELETE_SELF
    | _IN_MOVE_SELF
    | _IN_ONLYDIR
)


def watch_dir(path: str) -> None:
    """Emit a JSON line whenever the current folder listing should refresh."""
    if path in ("trash://", "trash:/", "trash:") or path.startswith("trash://"):
        target = trash_root() / "files"
        target.mkdir(parents=True, exist_ok=True)
        watch_path = str(target)
    else:
        watch_path = str(Path(path).expanduser())
        if not os.path.isdir(watch_path):
            err(f"Not a directory: {path}")

    libc_name = ctypes.util.find_library("c") or "libc.so.6"
    libc = ctypes.CDLL(libc_name, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_init1.restype = ctypes.c_int
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    libc.inotify_add_watch.restype = ctypes.c_int

    fd = libc.inotify_init1(_IN_CLOEXEC)
    if fd < 0:
        err("inotify init failed")
    wd = libc.inotify_add_watch(fd, os.fsencode(watch_path), _IN_DIR_EVENTS)
    if wd < 0:
        os.close(fd)
        err(f"inotify watch failed: {watch_path}")

    emit({"type": "ready", "ok": True, "path": watch_path})
    try:
        while True:
            try:
                data = os.read(fd, 65536)
            except InterruptedError:
                continue
            if not data:
                break
            emit({"type": "change", "ok": True})
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


REAL_FS = {
    "ext2",
    "ext3",
    "ext4",
    "btrfs",
    "xfs",
    "f2fs",
    "ntfs",
    "ntfs3",
    "vfat",
    "exfat",
    "fuseblk",
    "fuse.ntfs",
    "fuse.exfat",
    "zfs",
}


def _is_useful_mount(point: str) -> bool:
    if not point or not point.startswith("/"):
        return False
    p = Path(point)
    try:
        if not p.is_dir():
            return False
    except OSError:
        return False
    skip_prefixes = (
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
    )
    if any(point == s or point.startswith(s + "/") for s in skip_prefixes):
        return False
    # Deep bind mounts under home (editor sandboxes, etc.)
    home = str(Path.home())
    if point.startswith(home + "/") and point.count("/") >= home.count("/") + 2:
        return False
    return True


def list_mounts() -> None:
    """Mounted volumes + unmounted removable volumes (Nautilus-style sidebar)."""
    try:
        raw = subprocess.check_output(
            [
                "lsblk",
                "-J",
                "-b",
                "-o",
                "NAME,LABEL,SIZE,FSUSED,FSSIZE,FSAVAIL,MOUNTPOINTS,TYPE,HOTPLUG,RM,TRAN,FSTYPE,PATH",
            ],
            text=True,
        )
        data = json.loads(raw)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        err(f"lsblk failed: {e}")

    mounts: list[dict[str, Any]] = []
    seen_mounts: set[str] = set()
    seen_devices: set[str] = set()

    def is_removable(rm: bool, hot: bool, tran: str, point: str = "") -> bool:
        return bool(
            rm
            or hot
            or tran in ("usb", "mmc")
            or (point.startswith("/run/media") if point else False)
            or (point.startswith("/media") if point else False)
        )

    def walk(dev: dict[str, Any], parent_rm: bool = False, parent_hot: bool = False, tran: str = "") -> None:
        rm = bool(dev.get("rm")) or parent_rm
        hot = bool(dev.get("hotplug")) or parent_hot
        tran = (dev.get("tran") or tran or "").lower()
        fstype = (dev.get("fstype") or "").lower()
        dtype = (dev.get("type") or "").lower()
        mp = dev.get("mountpoints")
        if mp is None:
            mp = dev.get("mountpoint")
        if isinstance(mp, list):
            points = [p for p in mp if p and p != "[SWAP]"]
        elif mp and mp != "[SWAP]":
            points = [mp]
        else:
            points = []

        device_name = dev.get("name") or ""
        device_path = (dev.get("path") or "").strip() or (f"/dev/{device_name}" if device_name else "")
        label = (dev.get("label") or "").strip()
        removable = is_removable(rm, hot, tran)

        for point in points:
            if point in seen_mounts:
                continue
            if not _is_useful_mount(point):
                continue
            if fstype and fstype not in REAL_FS and not fstype.startswith("fuse"):
                if point not in ("/", "/home") and not point.startswith(("/run/media", "/media", "/mnt")):
                    continue
            fssize = int(dev.get("fssize") or 0)
            fsused = int(dev.get("fsused") or 0)
            fsavail = int(dev.get("fsavail") or 0)
            if fssize <= 0:
                continue
            seen_mounts.add(point)
            if device_path:
                seen_devices.add(device_path)
            name = label or Path(point).name or device_name or point
            if point == "/":
                name = "System"
            elif point == str(Path.home()) or point == "/home":
                name = "Home"
            rem = is_removable(rm, hot, tran, point)
            mounts.append(
                {
                    "name": name,
                    "device": device_name,
                    "devicePath": device_path,
                    "mount": point,
                    "label": label,
                    "fstype": fstype,
                    "total": fssize,
                    "used": fsused,
                    "free": fsavail if fsavail else max(0, fssize - fsused),
                    "perc": (fsused / fssize) if fssize else 0,
                    "removable": rem,
                    "mounted": True,
                    "ejectable": rem and point not in ("/", "/home", str(Path.home())),
                    "tran": tran,
                }
            )

        # Unmounted removable filesystems (still plugged in) — like Nautilus
        if not points and removable and device_path and device_path not in seen_devices:
            if dtype in ("part", "crypt") or (dtype == "disk" and fstype):
                if fstype and (fstype in REAL_FS or fstype.startswith("fuse")):
                    size = int(dev.get("size") or 0)
                    name = label or device_name or device_path
                    seen_devices.add(device_path)
                    mounts.append(
                        {
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
                            "removable": True,
                            "mounted": False,
                            "ejectable": False,
                            "tran": tran,
                        }
                    )

        for child in dev.get("children") or []:
            walk(child, rm, hot, tran)

    for block in data.get("blockdevices") or []:
        walk(block)

    def sort_key(m: dict[str, Any]) -> tuple:
        mount = m.get("mount") or ""
        return (
            0 if mount == "/" else 1,
            0 if not m.get("removable") else 1,
            0 if m.get("mounted") else 1,
            (m.get("name") or "").casefold(),
        )

    mounts.sort(key=sort_key)
    out({"ok": True, "mounts": mounts})


def _block_source_for_mount(mount_point: str) -> str:
    try:
        src = subprocess.check_output(
            ["findmnt", "-n", "-o", "SOURCE", "--target", mount_point],
            text=True,
            errors="replace",
        ).strip()
        if src:
            return src.split("[", 1)[0].strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return ""


def _disk_for_partition(device: str) -> str:
    if not device:
        return ""
    try:
        # Whole disk already (no parent)
        pk = subprocess.check_output(
            ["lsblk", "-no", "PKNAME", device],
            text=True,
            errors="replace",
        ).strip().splitlines()
        parent = (pk[0] if pk else "").strip()
        if parent:
            return f"/dev/{parent}"
        # Confirm it's a disk node
        dtype = subprocess.check_output(
            ["lsblk", "-no", "TYPE", device],
            text=True,
            errors="replace",
        ).strip().splitlines()
        if dtype and dtype[0].strip() in ("disk", "rom"):
            return device
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return device


def _mounted_partitions_on_disk(disk: str) -> list[str]:
    """Return block devices under disk that currently have a mountpoint."""
    if not disk:
        return []
    try:
        raw = subprocess.check_output(
            ["lsblk", "-J", "-o", "NAME,PATH,TYPE,MOUNTPOINTS", disk],
            text=True,
            errors="replace",
        )
        data = json.loads(raw)
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return []

    devices: list[str] = []

    def walk(node: dict[str, Any]) -> None:
        mp = node.get("mountpoints")
        if mp is None:
            mp = node.get("mountpoint")
        if isinstance(mp, list):
            points = [p for p in mp if p and p != "[SWAP]"]
        elif mp and mp != "[SWAP]":
            points = [mp]
        else:
            points = []
        path = (node.get("path") or "").strip()
        if not path and node.get("name"):
            path = f"/dev/{node['name']}"
        if points and path:
            devices.append(path)
        for child in node.get("children") or []:
            walk(child)

    for block in data.get("blockdevices") or []:
        walk(block)
    return devices


def _run_cmd(cmd: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    except FileNotFoundError as e:
        return 127, str(e)
    msg = (proc.stderr or proc.stdout or "").strip()
    return proc.returncode, msg


def _mount_targets_for_device(device: str) -> list[str]:
    try:
        out_txt = subprocess.check_output(
            ["findmnt", "-n", "-o", "TARGET", "-S", device],
            text=True,
            errors="replace",
        )
        return [line.strip() for line in out_txt.splitlines() if line.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []


def _is_mount_live(mount_point: str) -> bool:
    try:
        return bool(
            subprocess.check_output(
                ["findmnt", "-n", "--target", mount_point],
                text=True,
                errors="replace",
            ).strip()
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def _busy_hint(mount_point: str) -> str:
    """Best-effort list of processes keeping the volume busy."""
    hints: list[str] = []
    for cmd in (
        ["fuser", "-vm", mount_point],
        ["lsof", "+f", "--", mount_point],
    ):
        code, msg = _run_cmd(cmd)
        if msg:
            # Keep it short for UI toasts
            lines = [ln.strip() for ln in msg.splitlines() if ln.strip()]
            hints.extend(lines[:6])
            break
    if not hints:
        return "Close apps/terminals using this drive, then try again."
    return "In use by: " + "; ".join(hints[:4])


def _unmount_block(device: str, *, force: bool = False, lazy: bool = False) -> str:
    """Unmount a block device. Returns empty string on success, else error text."""
    udisks = ["udisksctl", "unmount", "-b", device, "--no-user-interaction"]
    if force:
        udisks.append("--force")
    code, msg = _run_cmd(udisks)
    if code == 0:
        return ""
    last = msg or f"failed to unmount {device}"

    for mp in _mount_targets_for_device(device):
        code, msg = _run_cmd(["gio", "mount", "-u", f"file://{mp}"])
        if code == 0:
            return ""
        if msg:
            last = msg
        umount_cmd = ["umount", "-l", mp] if lazy else ["umount", mp]
        if force and not lazy:
            umount_cmd = ["umount", "-f", mp]
        code, msg = _run_cmd(umount_cmd)
        if code == 0:
            return ""
        if msg:
            last = msg

    return last


def _device_node_exists(device: str) -> bool:
    if not device:
        return False
    try:
        return Path(device).exists()
    except OSError:
        return False


def do_eject(mount_point: str) -> None:
    """Real eject (udiskie tray "Eject" / gio -e) — not plain unmount, not Unpower."""
    mp = str(Path(mount_point).expanduser())
    if mp in ("/", "/home", str(Path.home())):
        err("Refusing to eject system volume")

    # Caller leaves the folder first; settle so thumbnails release FDs.
    time.sleep(0.5)

    uri = f"file://{mp}"
    source = _block_source_for_mount(mp) if _is_mount_live(mp) else ""
    disk = _disk_for_partition(source) if source else ""

    # Same action as udiskie tray "Eject /dev/sdX".
    udie_code, udie_msg = _run_cmd(
        ["udiskie-umount", "--eject", "--no-detach", "--force", mp]
    )
    if udie_code == 0:
        out(
            {
                "ok": True,
                "mount": mp,
                "device": source or "",
                "disk": disk or "",
                "poweredOff": False,
                "mode": "eject",
                "via": "udiskie",
            }
        )
        return

    if not _is_mount_live(mp):
        if disk and _device_node_exists(disk):
            _run_cmd(["gio", "mount", "-e", uri])
        out(
            {
                "ok": True,
                "mount": mp,
                "device": source or "",
                "disk": disk or "",
                "mode": "eject",
                "alreadyUnmounted": True,
                "poweredOff": False,
                "via": "gio",
            }
        )
        return

    code, msg = _run_cmd(["gio", "mount", "-e", uri])
    if code != 0 and _is_mount_live(mp):
        time.sleep(0.4)
        _run_cmd(["gio", "mount", "-e", "-f", uri])

    if _is_mount_live(mp):
        code, umsg = _run_cmd(["gio", "mount", "-u", "-f", uri])
        if _is_mount_live(mp):
            detail = umsg or msg or udie_msg or "Device is busy"
            err(detail + "\n" + _busy_hint(mp))
        if disk and _device_node_exists(disk):
            time.sleep(0.2)
            _run_cmd(["gio", "mount", "-e", uri])

    out(
        {
            "ok": True,
            "mount": mp,
            "device": source or "",
            "disk": disk or "",
            "poweredOff": False,
            "mode": "eject",
            "via": "gio",
        }
    )


def do_mount(device: str) -> None:
    """Mount a block device and return mountpoint.

    After eject, gvfs often has no Volume for the block id ("Nenhum volume para o ID dado").
    Prefer udisksctl (same stack as udiskie), then udiskie-mount, then gio.
    """
    dev = str(device).strip()
    if not dev:
        err("No device")

    existing = _mount_targets_for_device(dev)
    if existing:
        out({"ok": True, "mount": existing[0], "device": dev, "alreadyMounted": True})
        return

    last_msg = ""
    mounted_ok = False

    code, msg = _run_cmd(["udisksctl", "mount", "-b", dev, "--no-user-interaction"])
    last_msg = msg or last_msg
    if code == 0:
        mounted_ok = True
        # "Mounted /dev/sda1 at /run/media/user/LABEL"
        if " at " in msg:
            mp = msg.split(" at ", 1)[1].strip()
            if mp and Path(mp).is_dir():
                out({"ok": True, "mount": mp, "device": dev, "via": "udisksctl"})
                return

    if not mounted_ok:
        code, msg = _run_cmd(["udiskie-mount", dev])
        last_msg = msg or last_msg
        if code == 0:
            mounted_ok = True

    if not mounted_ok:
        code, msg = _run_cmd(["gio", "mount", "-d", dev])
        last_msg = msg or last_msg
        if code == 0:
            mounted_ok = True

    if not mounted_ok:
        err(last_msg or f"Failed to mount {dev}")

    targets = _mount_targets_for_device(dev)
    if not targets:
        time.sleep(0.3)
        targets = _mount_targets_for_device(dev)
    if not targets:
        err(last_msg or f"Mounted but mountpoint not found for {dev}")

    out({"ok": True, "mount": targets[0], "device": dev})


def zip_top_level(zf: zipfile.ZipFile) -> tuple[list[str], list[str]]:
    dirs: set[str] = set()
    files: set[str] = set()
    for info in zf.infolist():
        name = info.filename.replace("\\", "/")
        if not name or name.startswith("__MACOSX"):
            continue
        parts = [p for p in name.split("/") if p]
        if not parts:
            continue
        if len(parts) == 1 and not info.is_dir():
            files.add(parts[0])
        else:
            dirs.add(parts[0])
            if len(parts) == 1 and info.is_dir():
                dirs.add(parts[0])
    # A path that appears only as prefix of files is still a dir
    for f in list(files):
        if f in dirs:
            files.discard(f)
    return sorted(dirs), sorted(files)


def find_7z() -> str | None:
    for name in ("7z", "7za", "7zr"):
        path = shutil.which(name)
        if path:
            return path
    return None


def find_bsdtar() -> str | None:
    return shutil.which("bsdtar") or shutil.which("tar")


def seven_top_level_via_7z(archive: Path, seven: str) -> tuple[list[str], list[str]]:
    raw = subprocess.check_output(
        [seven, "l", "-ba", "-slt", str(archive)],
        text=True,
        errors="replace",
    )
    dirs: set[str] = set()
    files: set[str] = set()
    path = ""
    is_dir = False
    for line in raw.splitlines():
        if line.startswith("Path = "):
            path = line[7:].replace("\\", "/")
        elif line.startswith("Folder = "):
            is_dir = line[9:].strip().lower() in ("+", "true", "yes", "1")
        elif line == "" and path:
            if path in (".",) or path.startswith("__MACOSX"):
                path = ""
                continue
            parts = [p for p in path.split("/") if p]
            if parts:
                if len(parts) == 1 and not is_dir:
                    files.add(parts[0])
                else:
                    dirs.add(parts[0])
            path = ""
            is_dir = False
    for f in list(files):
        if f in dirs:
            files.discard(f)
    return sorted(dirs), sorted(files)


def seven_top_level_via_bsdtar(archive: Path, tar: str) -> tuple[list[str], list[str]]:
    raw = subprocess.check_output([tar, "-tf", str(archive)], text=True, errors="replace")
    dirs: set[str] = set()
    files: set[str] = set()
    for line in raw.splitlines():
        name = line.strip().replace("\\", "/")
        if not name or name.startswith("__MACOSX"):
            continue
        is_dir = name.endswith("/")
        parts = [p for p in name.split("/") if p]
        if not parts:
            continue
        if len(parts) == 1 and not is_dir:
            files.add(parts[0])
        else:
            dirs.add(parts[0])
    for f in list(files):
        if f in dirs:
            files.discard(f)
    return sorted(dirs), sorted(files)


def seven_top_level(archive: Path) -> tuple[list[str], list[str]]:
    seven = find_7z()
    if seven:
        try:
            return seven_top_level_via_7z(archive, seven)
        except subprocess.CalledProcessError as e:
            err(f"7z list failed: {e}")

    tar = find_bsdtar()
    if tar:
        try:
            return seven_top_level_via_bsdtar(archive, tar)
        except subprocess.CalledProcessError as e:
            err(f"Archive list failed: {e}")

    err("No archive tool found. Install 7zip (or p7zip) to extract .7z files.")


def extract_zip(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "r") as zf:
        infos = [i for i in zf.infolist() if not i.filename.startswith("__MACOSX")]
        total = sum(max(0, i.file_size) for i in infos) or 1
        done = 0
        for idx, info in enumerate(infos):
            zf.extract(info, dest)
            done += max(0, info.file_size)
            pct = max(done / total, (idx + 1) / max(1, len(infos)))
            progress(min(0.95, pct), f"Extracting {Path(info.filename).name}")


def seven_uncompressed_size(archive: Path, seven: str) -> int:
    raw = subprocess.check_output(
        [seven, "l", "-ba", "-slt", str(archive)],
        text=True,
        errors="replace",
    )
    total = 0
    path = ""
    is_dir = False
    size = 0
    for line in raw.splitlines():
        if line.startswith("Path = "):
            path = line[7:].replace("\\", "/")
            is_dir = False
            size = 0
        elif line.startswith("Folder = "):
            is_dir = line[9:].strip().lower() in ("+", "true", "yes", "1")
        elif line.startswith("Size = "):
            try:
                size = int(line[7:].strip())
            except ValueError:
                size = 0
        elif line == "" and path:
            if path not in (".",) and not path.startswith("__MACOSX") and not is_dir and not path.endswith("/"):
                total += max(0, size)
            path = ""
            is_dir = False
            size = 0
    return total


def _apply_backspaces(text: str) -> str:
    out: list[str] = []
    for ch in text:
        if ch == "\b":
            if out:
                out.pop()
        elif ch != "\r":
            out.append(ch)
    return "".join(out)


def extract_7z_via_bsdtar(archive: Path, dest: Path, tar: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    progress(0.08, "Extracting archive")
    proc = subprocess.Popen(
        [tar, "-xf", str(archive), "-C", str(dest)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    # bsdtar has no % stream — nudge progress while running
    last = 0.08
    while proc.poll() is None:
        time.sleep(0.15)
        last = min(0.9, last + 0.04)
        progress(last, "Extracting archive")
    _stderr = proc.stderr.read() if proc.stderr else ""
    if proc.returncode != 0:
        msg = (_stderr or "").strip() or f"exit {proc.returncode}"
        err(f"Archive extract failed: {msg}")
    progress(0.96, "Finishing…")


def extract_7z(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    seven = find_7z()
    if not seven:
        tar = find_bsdtar()
        if tar:
            extract_7z_via_bsdtar(archive, dest, tar)
            return
        err("No archive tool found. Install 7zip (package: 7zip) to extract .7z files.")

    expected = 0
    try:
        expected = seven_uncompressed_size(archive, seven)
    except (subprocess.CalledProcessError, FileNotFoundError):
        expected = 0

    progress(0.05, "Extracting archive")
    proc = subprocess.Popen(
        [seven, "x", "-y", "-bsp1", "-bso0", "-bse0", f"-o{dest}", str(archive)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
    )
    assert proc.stdout is not None

    stop = threading.Event()
    last_box: list[float] = [0.05]

    def emit_pct(pct: float, label: str = "Extracting archive") -> None:
        pct = min(0.95, max(0.05, pct))
        if pct - last_box[0] >= 0.01 or pct >= 0.95:
            last_box[0] = pct
            progress(pct, label)

    def poll_dest() -> None:
        while not stop.wait(0.12):
            if expected <= 0:
                emit_pct(min(0.9, last_box[0] + 0.03))
                continue
            try:
                cur = float(_path_size(dest))
            except Exception:
                continue
            emit_pct(cur / expected)

    poller = threading.Thread(target=poll_dest, daemon=True)
    poller.start()

    raw = b""
    try:
        while True:
            chunk = proc.stdout.read(64)
            if not chunk:
                break
            raw += chunk
            text = _apply_backspaces(raw.decode("utf-8", errors="replace"))
            matches = list(re.finditer(r"(\d+)\s*%", text))
            if matches:
                emit_pct(int(matches[-1].group(1)) / 100.0)
    finally:
        stop.set()
        poller.join(timeout=1.0)

    rc = proc.wait()
    if rc != 0:
        err(f"7z extract failed (exit {rc})")
    progress(0.96, "Finishing…")


def planned_extract_target(dest: Path, archive_stem: str, top_dirs: list[str], top_files: list[str]) -> Path:
    if len(top_dirs) == 1 and len(top_files) == 0:
        return dest / top_dirs[0]
    if len(top_dirs) == 0 and len(top_files) == 1:
        return dest / top_files[0]
    return dest / archive_stem


def smart_extract(archive_path: str, dest_dir: str | None) -> None:
    archive = Path(archive_path).expanduser().resolve()
    if not archive.is_file():
        err(f"Archive not found: {archive_path}")

    dest = Path(dest_dir).expanduser().resolve() if dest_dir else archive.parent
    if not dest.is_dir():
        err(f"Destination is not a directory: {dest}")

    ext = archive.suffix.lower()
    if ext == ".7zip":
        ext = ".7z"
    if ext not in ARCHIVE_EXTS:
        err(f"Unsupported archive type: {ext}")

    progress(0.02, "Inspecting archive…")
    if ext == ".zip":
        with zipfile.ZipFile(archive, "r") as zf:
            top_dirs, top_files = zip_top_level(zf)
        extract_fn = extract_zip
    else:
        top_dirs, top_files = seven_top_level(archive)
        extract_fn = extract_7z

    base = archive.stem
    # Fail early — don't extract to temp if destination already exists (Nautilus/Dolphin style)
    planned = planned_extract_target(dest, base, top_dirs, top_files)
    if planned.exists():
        err(f"Already exists: {planned}")

    with tempfile.TemporaryDirectory(prefix="donwaztok-fm-") as tmp:
        tmp_path = Path(tmp)
        extract_fn(archive, tmp_path)

        for junk in tmp_path.glob("__MACOSX"):
            shutil.rmtree(junk, ignore_errors=True)
        for junk in tmp_path.glob("**/.DS_Store"):
            try:
                junk.unlink()
            except OSError:
                pass

        children = [c for c in tmp_path.iterdir() if c.name != "__MACOSX"]
        progress(0.97, "Placing files…")

        if len(top_dirs) == 1 and len(top_files) == 0 and len(children) == 1 and children[0].is_dir():
            src = children[0]
            target = dest / src.name
            if target.exists():
                err(f"Already exists: {target}")
            shutil.move(str(src), str(target))
            result = target
        elif len(top_dirs) == 0 and len(top_files) == 1 and len(children) == 1 and children[0].is_file():
            src = children[0]
            target = dest / src.name
            if target.exists():
                err(f"Already exists: {target}")
            shutil.move(str(src), str(target))
            result = target
        else:
            target = dest / base
            if target.exists():
                err(f"Already exists: {target}")
            target.mkdir(parents=True)
            for child in children:
                shutil.move(str(child), str(target / child.name))
            result = target

    progress(1.0, "Done")
    out(
        {
            "ok": True,
            "archive": str(archive),
            "result": str(result),
            "isDir": result.is_dir(),
            "mode": (
                "single-root-folder"
                if len(top_dirs) == 1 and not top_files
                else "single-file"
                if len(top_files) == 1 and not top_dirs
                else "wrapped-folder"
            ),
        }
    )


def do_mkdir(path: str) -> None:
    p = Path(path).expanduser()
    p.mkdir(parents=False, exist_ok=False)
    out({"ok": True, "path": str(p)})


def do_rename(src: str, dst: str) -> None:
    s = Path(src).expanduser()
    d = Path(dst).expanduser()
    if d.exists():
        err(f"Already exists: {d}")
    s.rename(d)
    out({"ok": True, "path": str(d)})


def _trash_name_from_uri(uri: str) -> str:
    u = str(uri or "").strip()
    for prefix in ("trash:///", "trash://", "trash:/"):
        if u.startswith(prefix):
            u = u[len(prefix) :]
            break
    try:
        from urllib.parse import unquote

        u = unquote(u)
    except Exception:
        pass
    # Only the trash entry basename is meaningful
    return Path(u).name


def _find_trash_entry_for_original(original: str) -> tuple[Path, Path, str] | None:
    """Return (files_path, info_path, trash_name) for an original path, if present."""
    info_dir = trash_root() / "info"
    files_dir = trash_root() / "files"
    if not info_dir.is_dir():
        return None

    expanded = Path(original).expanduser()
    wanted = {str(expanded)}
    try:
        wanted.add(str(expanded.resolve()))
    except OSError:
        pass

    best = None
    best_mtime = -1.0
    for info_path in info_dir.glob("*.trashinfo"):
        meta = parse_trashinfo(info_path)
        orig = meta.get("original") or ""
        if orig not in wanted:
            continue
        name = info_path.name[: -len(".trashinfo")]
        files_path = files_dir / name
        if not files_path.exists():
            continue
        try:
            mtime = info_path.stat().st_mtime
        except OSError:
            mtime = 0
        if mtime >= best_mtime:
            best_mtime = mtime
            best = (files_path, info_path, name)
    return best


def _restore_trash_entry(files_path: Path, info_path: Path, original: str) -> str:
    dst = Path(original).expanduser()
    if dst.exists():
        err(f"Already exists: {dst}")
    if not files_path.exists():
        err(f"Missing trash file: {files_path}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(files_path), str(dst))
    try:
        info_path.unlink(missing_ok=True)
    except OSError:
        pass
    return str(dst)


def do_trash(paths: list[str]) -> None:
    originals: list[str] = []
    for raw in paths:
        p = Path(raw).expanduser()
        try:
            originals.append(str(p.resolve()))
        except OSError:
            originals.append(str(p))

    for p in originals:
        subprocess.check_call(["gio", "trash", p])

    # Map via .trashinfo — gio trash --list/--restore are unsupported on some setups
    items: list[dict[str, str]] = []
    for original in originals:
        found = _find_trash_entry_for_original(original)
        if not found:
            continue
        files_path, _info_path, name = found
        items.append(
            {
                "uri": f"trash:///{name}",
                "trashName": name,
                "original": original,
                "name": Path(original).name,
                "trashPath": str(files_path),
            }
        )

    out({"ok": True, "count": len(paths), "items": items})


def do_restore(uris: list[str]) -> None:
    """Restore from trash using Trash/files + .trashinfo (gio --restore may be unsupported)."""
    restored = []
    files_dir = trash_root() / "files"
    info_dir = trash_root() / "info"

    for uri in uris:
        name = _trash_name_from_uri(uri)
        info_path = info_dir / f"{name}.trashinfo"
        files_path = files_dir / name

        if name and info_path.is_file() and files_path.exists():
            original = parse_trashinfo(info_path).get("original") or ""
            if original:
                restored.append(_restore_trash_entry(files_path, info_path, original))
                continue

        if uri and not str(uri).startswith("trash:"):
            found = _find_trash_entry_for_original(uri)
            if found:
                fp, ip, _n = found
                orig = parse_trashinfo(ip).get("original") or uri
                restored.append(_restore_trash_entry(fp, ip, orig))
                continue

        try:
            subprocess.check_call(["gio", "trash", "--restore", uri])
            restored.append(uri)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            err(f"Cannot restore {uri}: {e}")

    out({"ok": True, "count": len(restored), "uris": restored, "paths": restored})


def _wipe_dir_contents(directory: Path) -> int:
    removed = 0
    if not directory.is_dir():
        return 0
    for child in list(directory.iterdir()):
        try:
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child, ignore_errors=True)
            else:
                child.unlink(missing_ok=True)
            removed += 1
        except OSError:
            pass
    return removed


def do_empty_trash() -> None:
    _run_cmd(["gio", "trash", "--empty"])
    root = trash_root()
    removed = 0
    for sub in ("files", "info", "expunged"):
        removed += _wipe_dir_contents(root / sub)
    out({"ok": True, "emptied": True, "count": removed})


def do_delete(paths: list[str]) -> None:
    for raw in paths:
        p = Path(raw).expanduser()
        # Also remove matching .trashinfo when deleting from Trash/files
        trash_files = trash_root() / "files"
        trash_info = trash_root() / "info"
        try:
            if trash_files in p.parents or p.parent == trash_files:
                info = trash_info / f"{p.name}.trashinfo"
                if info.exists():
                    info.unlink(missing_ok=True)
        except OSError:
            pass
        if p.is_dir() and not p.is_symlink():
            shutil.rmtree(p)
        else:
            p.unlink(missing_ok=True)
    out({"ok": True, "count": len(paths)})


def _path_size(path: Path) -> int:
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0
    total = 0
    if path.is_dir():
        for root, _dirs, files in os.walk(path):
            for name in files:
                try:
                    total += (Path(root) / name).stat().st_size
                except OSError:
                    pass
    return total


def _copy_file_with_progress(src: Path, dst: Path, copied: list[int], total: int, label: str) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    size = 0
    try:
        size = src.stat().st_size
    except OSError:
        pass
    with src.open("rb") as rf, dst.open("wb") as wf:
        while True:
            chunk = rf.read(1024 * 1024)
            if not chunk:
                break
            wf.write(chunk)
            copied[0] += len(chunk)
            if total > 0:
                progress(min(0.99, copied[0] / total), label)
    shutil.copystat(src, dst, follow_symlinks=False)


def _copy_tree_with_progress(src: Path, dst: Path, copied: list[int], total: int) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    for root, dirs, files in os.walk(src):
        rel = Path(root).relative_to(src)
        target_root = dst / rel
        target_root.mkdir(parents=True, exist_ok=True)
        for d in dirs:
            (target_root / d).mkdir(parents=True, exist_ok=True)
        for name in files:
            s = Path(root) / name
            t = target_root / name
            _copy_file_with_progress(s, t, copied, total, f"Copying {name}")


def do_copy(sources: list[str], dest_dir: str) -> None:
    dest = Path(dest_dir).expanduser()
    if not dest.is_dir():
        err(f"Not a directory: {dest_dir}")
    srcs = [Path(raw).expanduser() for raw in sources]
    total = sum(_path_size(s) for s in srcs) or 1
    copied = [0]
    results = []
    progress(0.0, "Preparing copy…")
    for src in srcs:
        target = dest / src.name
        if target.exists():
            stem, suffix = src.stem, src.suffix
            n = 1
            while target.exists():
                target = dest / f"{stem} ({n}){suffix}"
                n += 1
        if src.is_dir():
            _copy_tree_with_progress(src, target, copied, total)
        else:
            _copy_file_with_progress(src, target, copied, total, f"Copying {src.name}")
        results.append(str(target))
    progress(1.0, "Done")
    out({"ok": True, "results": results})


def do_move(sources: list[str], dest_dir: str) -> None:
    dest = Path(dest_dir).expanduser()
    if not dest.is_dir():
        err(f"Not a directory: {dest_dir}")
    results = []
    items = []
    n = len(sources) or 1
    for i, raw in enumerate(sources):
        src = Path(raw).expanduser()
        target = dest / src.name
        if target.exists():
            err(f"Already exists: {target}")
        progress(i / n, f"Moving {src.name}")
        shutil.move(str(src), str(target))
        results.append(str(target))
        items.append({"from": str(src), "to": str(target)})
    progress(1.0, "Done")
    out({"ok": True, "results": results, "items": items, "count": len(items)})


def do_undo_move(pairs: list[str]) -> None:
    """Restore moved items. Args are flat: to1 from1 to2 from2 …"""
    if len(pairs) < 2 or len(pairs) % 2 != 0:
        err("undo-move expects to/from path pairs")
    n = len(pairs) // 2
    restored = []
    for i in range(0, len(pairs), 2):
        src = Path(pairs[i]).expanduser()  # current location
        dst = Path(pairs[i + 1]).expanduser()  # original path
        progress(i / (len(pairs) or 1), f"Restoring {dst.name}")
        if not src.exists():
            err(f"Missing: {src}")
        if dst.exists():
            err(f"Already exists: {dst}")
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))
        restored.append(str(dst))
    progress(1.0, "Done")
    out({"ok": True, "results": restored, "count": len(restored)})


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list")
    p_list.add_argument("path")
    p_list.add_argument("--hidden", action="store_true")

    sub.add_parser("mounts")

    sub.add_parser("xdg-dirs")

    p_ext = sub.add_parser("smart-extract")
    p_ext.add_argument("archive")
    p_ext.add_argument("--dest", default=None)

    p_mkdir = sub.add_parser("mkdir")
    p_mkdir.add_argument("path")

    p_ren = sub.add_parser("rename")
    p_ren.add_argument("src")
    p_ren.add_argument("dst")

    p_trash = sub.add_parser("trash")
    p_trash.add_argument("paths", nargs="+")

    p_restore = sub.add_parser("restore")
    p_restore.add_argument("uris", nargs="+")

    p_empty = sub.add_parser("empty-trash")

    p_del = sub.add_parser("delete")
    p_del.add_argument("paths", nargs="+")

    p_copy = sub.add_parser("copy")
    p_copy.add_argument("dest")
    p_copy.add_argument("sources", nargs="+")

    p_move = sub.add_parser("move")
    p_move.add_argument("dest")
    p_move.add_argument("sources", nargs="+")

    p_undo_move = sub.add_parser("undo-move")
    p_undo_move.add_argument("pairs", nargs="+", help="to from to from …")

    p_eject = sub.add_parser("eject")
    p_eject.add_argument("mount")

    p_mount = sub.add_parser("mount")
    p_mount.add_argument("device")

    p_open = sub.add_parser("open")
    p_open.add_argument("path")

    p_thumb = sub.add_parser("thumb")
    p_thumb.add_argument("path")
    p_thumb.add_argument("dest")
    p_thumb.add_argument("--size", type=int, default=64)

    p_info = sub.add_parser("info")
    p_info.add_argument("paths", nargs="+")

    p_watch = sub.add_parser("watch")
    p_watch.add_argument("path")

    args = parser.parse_args()

    try:
        if args.cmd == "list":
            list_dir(args.path, args.hidden)
        elif args.cmd == "mounts":
            list_mounts()
        elif args.cmd == "xdg-dirs":
            xdg_dirs()
        elif args.cmd == "smart-extract":
            smart_extract(args.archive, args.dest)
        elif args.cmd == "mkdir":
            do_mkdir(args.path)
        elif args.cmd == "rename":
            do_rename(args.src, args.dst)
        elif args.cmd == "trash":
            do_trash(args.paths)
        elif args.cmd == "restore":
            do_restore(args.uris)
        elif args.cmd == "empty-trash":
            do_empty_trash()
        elif args.cmd == "delete":
            do_delete(args.paths)
        elif args.cmd == "copy":
            do_copy(args.sources, args.dest)
        elif args.cmd == "move":
            do_move(args.sources, args.dest)
        elif args.cmd == "undo-move":
            do_undo_move(args.pairs)
        elif args.cmd == "eject":
            do_eject(args.mount)
        elif args.cmd == "mount":
            do_mount(args.device)
        elif args.cmd == "open":
            do_open(args.path)
        elif args.cmd == "thumb":
            do_thumb(args.path, args.dest, args.size)
        elif args.cmd == "info":
            do_info(args.paths)
        elif args.cmd == "watch":
            watch_dir(args.path)
    except SystemExit:
        raise
    except Exception as e:
        err(str(e))


if __name__ == "__main__":
    main()
