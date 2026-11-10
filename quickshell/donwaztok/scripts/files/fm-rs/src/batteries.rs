//! Wireless USB devices that do not publish a battery to UPower.
//!
//! Logitech receivers already show up as hidpp power supplies, so they are skipped.
//! A Logitech keyboard or mouse plugged in by cable is charging, but the kernel does
//! not publish its battery in wired mode, so it is listed without a percentage.
//! The 8BitDo Ultimate 2 reports a percentage only in DirectInput mode (USB 6012),
//! in the 34-byte pad report. XInput mode (USB 310b) does not carry charge.
//! The HyperX Cloud Stinger Core dongle does not answer a battery query.

use serde_json::{json, Value};
use std::fs;
use std::io::Read;
use std::os::fd::AsRawFd;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

const USB_DEVICES: &str = "/sys/bus/usb/devices";
// Same reach as the os.walk of the Python version (it pruned below depth 6).
const MAX_DEPTH: usize = 8;

fn read_text(path: &Path) -> String {
    fs::read(path).map(|b| String::from_utf8_lossy(&b).trim().to_string()).unwrap_or_default()
}

fn walk(device: &Path) -> impl Iterator<Item = walkdir::DirEntry> {
    WalkDir::new(device).min_depth(1).max_depth(MAX_DEPTH).into_iter().filter_map(Result::ok)
}

fn has_power_supply(device: &Path) -> bool {
    walk(device).any(|e| e.file_name() == "power_supply" && e.path().is_dir())
}

fn classify(vendor: &str, name: &str) -> &'static str {
    let lowered = name.to_lowercase();
    let has = |s: &str| lowered.contains(s);
    if vendor == "046d" {
        return if has("receiver") {
            ""
        } else if has("keyboard") || has("pro x 60") {
            "keyboard"
        } else if has("mouse") {
            "mouse"
        } else {
            ""
        };
    }
    if vendor == "2dc8" || has("8bitdo") {
        return "controller";
    }
    if (vendor == "0951" && (has("hyperx") || has("stinger"))) || has("headset") || has("headphone") {
        return "headset";
    }
    ""
}

fn hidraw_nodes(device: &Path) -> Vec<PathBuf> {
    walk(device)
        .filter(|e| e.file_type().is_dir() && e.file_name() == "hidraw" && e.depth() < MAX_DEPTH)
        .filter_map(|e| fs::read_dir(e.path()).ok())
        .flatten()
        .filter_map(Result::ok)
        .filter(|n| n.file_name().to_string_lossy().starts_with("hidraw"))
        .map(|n| Path::new("/dev").join(n.file_name()))
        .collect()
}

/// SDL's 8BitDo driver: report id in byte 0, charge in byte 14 of a 34-byte report.
fn parse_8bitdo_report(data: &[u8]) -> Option<(u8, &'static str)> {
    if data.len() < 34 || !matches!(data[0], 0x01 | 0x03 | 0x04) {
        return None;
    }
    let level = data[14] & 0x7F;
    if level > 100 {
        return None;
    }
    let status = if level == 100 { 2 } else { data[14] >> 7 };
    Some((level, ["discharging", "charging", "full"][status as usize]))
}

fn read_8bitdo_directinput(device: &Path) -> Option<(u8, &'static str)> {
    for node in hidraw_nodes(device) {
        let Ok(mut f) = fs::OpenOptions::new().read(true).custom_flags(libc::O_NONBLOCK).open(&node) else {
            continue;
        };
        for _ in 0..4 {
            let mut pfd = libc::pollfd { fd: f.as_raw_fd(), events: libc::POLLIN, revents: 0 };
            if unsafe { libc::poll(&mut pfd, 1, 50) } <= 0 {
                continue;
            }
            let mut buf = [0u8; 128];
            if let Ok(n) = f.read(&mut buf) {
                if let Some(parsed) = parse_8bitdo_report(&buf[..n]) {
                    return Some(parsed);
                }
            }
        }
    }
    None
}

fn clean_name(name: &str, kind: &str) -> String {
    let mut cleaned = name.split_whitespace().collect::<Vec<_>>().join(" ").replace("8BitDo 8BitDo", "8BitDo");
    if cleaned.contains("Cloud Stinger Core") {
        return "HyperX Cloud Stinger Core".into();
    }
    if kind == "controller" {
        for suffix in [" for PC", " Wireless Controller", " Controller"] {
            if let Some(stripped) = cleaned.strip_suffix(suffix) {
                cleaned = stripped.trim_end().to_string();
            }
        }
    }
    if cleaned.is_empty() {
        name.to_string()
    } else {
        cleaned
    }
}

pub fn list() {
    let mut entries: Vec<String> = fs::read_dir(USB_DEVICES)
        .map(|rd| rd.filter_map(Result::ok).map(|e| e.file_name().to_string_lossy().into_owned()).collect())
        .unwrap_or_default();
    entries.sort();
    let mut devices: Vec<Value> = vec![];
    for entry in entries.iter().filter(|e| !e.contains(':')) {
        let device = Path::new(USB_DEVICES).join(entry);
        if !device.is_dir() {
            continue;
        }
        let vendor = read_text(&device.join("idVendor")).to_lowercase();
        let product = read_text(&device.join("idProduct")).to_lowercase();
        let name = read_text(&device.join("product"));
        if vendor.is_empty() || name.is_empty() || has_power_supply(&device) {
            continue;
        }
        let kind = classify(&vendor, &name);
        if kind.is_empty() {
            continue;
        }
        let (mut percent, mut state, mut detail) = (None, "unknown", "");
        match (vendor.as_str(), product.as_str()) {
            ("2dc8", "6012") => {
                if let Some((p, s)) = read_8bitdo_directinput(&device) {
                    (percent, state) = (Some(p), s);
                }
            }
            ("2dc8", _) => detail = "XInput mode does not report charge",
            ("046d", _) => (state, detail) = ("charging", "Charging via cable"),
            ("0951", _) => detail = "Dongle does not report charge",
            _ => {}
        }
        devices.push(json!({
            "key": format!("usb-{vendor}-{product}-{entry}"),
            "name": clean_name(&name, kind),
            "kind": kind,
            "percent": percent,
            "state": state,
            "detail": detail,
        }));
    }
    println!("{}", json!({"devices": devices}));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_and_names() {
        let mut r = [0u8; 34];
        r[0] = 0x03;
        r[14] = 0x80 | 55;
        assert_eq!(parse_8bitdo_report(&r), Some((55, "charging")));
        r[14] = 100;
        assert_eq!(parse_8bitdo_report(&r), Some((100, "full")));
        r[14] = 101;
        assert_eq!(parse_8bitdo_report(&r), None);
        assert_eq!(parse_8bitdo_report(&r[..33]), None);
        assert_eq!(clean_name("8BitDo  8BitDo Ultimate 2 Wireless Controller for PC", "controller"), "8BitDo Ultimate 2");
        assert_eq!(classify("046d", "USB Receiver"), "");
        assert_eq!(classify("0951", "HyperX Cloud Stinger Core Wireless"), "headset");
    }
}
