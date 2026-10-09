#!/usr/bin/env python3
"""List wireless USB devices that do not publish a battery to UPower.

Logitech receivers already show up as hidpp power supplies, so they are skipped.
The 8BitDo Ultimate 2 reports a percentage only in DirectInput mode (USB 6012),
in the 34-byte pad report. XInput mode (USB 310b) does not carry charge.
The HyperX Cloud Stinger Core dongle does not answer a battery query.
"""

import json
import os
import select

USB_DEVICES = "/sys/bus/usb/devices"


def read_text(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read().strip()
    except OSError:
        return ""


def has_power_supply(device_path: str) -> bool:
    for root, dirs, _files in os.walk(device_path):
        if "power_supply" in dirs:
            return True
        # Avoid walking into unrelated class links.
        depth = root[len(device_path):].count(os.sep)
        if depth > 6:
            dirs.clear()
    return False


def classify(vendor: str, product: str, name: str) -> str:
    lowered = name.lower()
    if vendor == "2dc8" or "8bitdo" in lowered:
        return "controller"
    if vendor == "0951" and ("hyperx" in lowered or "stinger" in lowered or "headset" in lowered):
        return "headset"
    if "headset" in lowered or "headphone" in lowered:
        return "headset"
    return ""


def hidraw_nodes(device_path: str) -> list[str]:
    nodes = []
    for root, dirs, _files in os.walk(device_path):
        if os.path.basename(root) == "hidraw":
            for name in os.listdir(root):
                if name.startswith("hidraw"):
                    nodes.append(os.path.join("/dev", name))
        depth = root[len(device_path):].count(os.sep)
        if depth > 6:
            dirs.clear()
    return nodes


def parse_8bitdo_report(data: bytes) -> tuple[int, str] | None:
    # SDL's 8BitDo driver: report id in byte 0, charge in byte 14 of a 34-byte report.
    if len(data) < 34 or data[0] not in (0x01, 0x03, 0x04):
        return None
    level = data[14] & 0x7F
    status = data[14] >> 7
    if level > 100:
        return None
    if level == 100:
        status = 2
    state = {0: "discharging", 1: "charging", 2: "full"}.get(status, "unknown")
    return level, state


def read_8bitdo_directinput(device_path: str) -> tuple[int, str] | None:
    for node in hidraw_nodes(device_path):
        try:
            fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        try:
            deadline_reads = 0
            while deadline_reads < 4:
                ready, _, _ = select.select([fd], [], [], 0.05)
                deadline_reads += 1
                if not ready:
                    continue
                try:
                    data = os.read(fd, 128)
                except BlockingIOError:
                    continue
                parsed = parse_8bitdo_report(data)
                if parsed is not None:
                    return parsed
        finally:
            os.close(fd)
    return None


def clean_name(name: str, kind: str) -> str:
    cleaned = " ".join(name.split())
    cleaned = cleaned.replace("8BitDo 8BitDo", "8BitDo")
    if "Cloud Stinger Core" in cleaned:
        return "HyperX Cloud Stinger Core"
    if kind == "controller":
        for suffix in (" for PC", " Wireless Controller", " Controller"):
            if cleaned.endswith(suffix):
                cleaned = cleaned[: -len(suffix)].rstrip()
    return cleaned or name


def main() -> None:
    devices = []
    try:
        entries = sorted(os.listdir(USB_DEVICES))
    except OSError:
        print(json.dumps({"devices": []}))
        return

    for entry in entries:
        if ":" in entry:
            continue
        device_path = os.path.join(USB_DEVICES, entry)
        if not os.path.isdir(device_path):
            continue
        vendor = read_text(os.path.join(device_path, "idVendor")).lower()
        product = read_text(os.path.join(device_path, "idProduct")).lower()
        name = read_text(os.path.join(device_path, "product"))
        if not vendor or not name:
            continue
        if vendor == "046d":
            continue
        if has_power_supply(device_path):
            continue
        kind = classify(vendor, product, name)
        if not kind:
            continue
        percent = None
        state = "unknown"
        detail = ""
        if vendor == "2dc8" and product == "6012":
            parsed = read_8bitdo_directinput(device_path)
            if parsed is not None:
                percent, state = parsed
        elif vendor == "2dc8":
            detail = "XInput mode does not report charge"
        elif vendor == "0951":
            detail = "Dongle does not report charge"
        devices.append({
            "key": f"usb-{vendor}-{product}-{entry}",
            "name": clean_name(name, kind),
            "kind": kind,
            "percent": percent,
            "state": state,
            "detail": detail,
        })

    print(json.dumps({"devices": devices}))


if __name__ == "__main__":
    main()
