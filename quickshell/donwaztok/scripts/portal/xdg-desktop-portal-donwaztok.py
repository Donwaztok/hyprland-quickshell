#!/usr/bin/env python3
"""xdg-desktop-portal FileChooser backend that opens Donwaztok Files."""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import quote

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")

from gi.repository import Gio, GLib  # noqa: E402

BUS_NAME = "org.freedesktop.impl.portal.desktop.donwaztok"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
IFACE = "org.freedesktop.impl.portal.FileChooser"
INTROSPECTION_XML = f"""
<node>
  <interface name="{IFACE}">
    <method name="OpenFile">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="title" direction="in"/>
      <arg type="a{{sv}}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
      <arg type="a{{sv}}" name="results" direction="out"/>
    </method>
    <method name="SaveFile">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="title" direction="in"/>
      <arg type="a{{sv}}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
      <arg type="a{{sv}}" name="results" direction="out"/>
    </method>
    <method name="SaveFiles">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="title" direction="in"/>
      <arg type="a{{sv}}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
      <arg type="a{{sv}}" name="results" direction="out"/>
    </method>
    <property type="u" name="version" access="read"/>
  </interface>
</node>
"""


def runtime_root() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    root = Path(base) / "donwaztok-portal"
    root.mkdir(parents=True, exist_ok=True)
    return root


def path_to_uri(path: str) -> str:
    p = Path(path).expanduser().resolve()
    return p.as_uri()


def decode_ay(value) -> str:
    if value is None:
        return ""
    raw = bytes(value)
    if raw.endswith(b"\x00"):
        raw = raw[:-1]
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("utf-8", errors="replace")


def unpack_variant(v):
    if isinstance(v, GLib.Variant):
        return v.unpack()
    return v


def parse_filters(options: dict) -> list[dict]:
    out: list[dict] = []
    filters = unpack_variant(options.get("filters")) if options else None
    if not filters:
        return [{"name": "All files", "patterns": ["*"]}]
    for name, rules in filters:
        patterns: list[str] = []
        for kind, pattern in rules:
            # 0 = glob
            if int(kind) == 0 and pattern:
                patterns.append(str(pattern))
        if not patterns:
            patterns = ["*"]
        out.append({"name": str(name) or "Files", "patterns": patterns})
    return out or [{"name": "All files", "patterns": ["*"]}]


def qs_bin() -> str:
    return shutil.which("qs") or "qs"


def launch_picker(request_id: str) -> bool:
    cmd = [qs_bin(), "-c", "donwaztok", "ipc", "call", "fileManager", "pick", request_id]
    try:
        proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as exc:
        sys.stderr.write(f"donwaztok-portal: failed to launch picker: {exc}\n")
        return False
    if proc.returncode != 0:
        sys.stderr.write(
            f"donwaztok-portal: qs ipc failed ({proc.returncode}): {proc.stderr or proc.stdout}\n"
        )
        return False
    return True


def wait_result(result_path: Path, timeout_s: float = 600.0) -> dict | None:
    deadline = time.monotonic() + timeout_s
    ctx = GLib.MainContext.default()
    while time.monotonic() < deadline:
        if result_path.is_file():
            try:
                data = json.loads(result_path.read_text(encoding="utf-8"))
                if isinstance(data, dict) and "response" in data:
                    return data
            except (OSError, json.JSONDecodeError):
                pass
        # Keep the D-Bus connection alive while waiting.
        ctx.iteration(False)
        time.sleep(0.05)
    return None


def options_dict(options_variant) -> dict:
    raw = unpack_variant(options_variant) or {}
    out = {}
    for key, val in raw.items():
        out[str(key)] = unpack_variant(val)
    return out


def build_request(mode: str, title: str, options: dict) -> tuple[str, Path, Path]:
    request_id = uuid.uuid4().hex
    folder = runtime_root() / request_id
    folder.mkdir(parents=True, exist_ok=True)
    request_path = folder / "request.json"
    result_path = folder / "result.json"
    if result_path.exists():
        result_path.unlink()

    filters = parse_filters(options)
    current_folder = decode_ay(options.get("current_folder")) if options.get("current_folder") is not None else ""
    current_file = decode_ay(options.get("current_file")) if options.get("current_file") is not None else ""
    current_name = str(options.get("current_name") or "")
    if not current_name and current_file:
        current_name = Path(current_file).name
        if not current_folder:
            current_folder = str(Path(current_file).parent)

    save_files: list[str] = []
    if mode == "saveFiles":
        for item in options.get("files") or []:
            name = decode_ay(item)
            if name:
                save_files.append(Path(name).name)

    payload = {
        "id": request_id,
        "mode": mode,
        "title": title or "",
        "acceptLabel": str(options.get("accept_label") or "").replace("_", ""),
        "multiple": bool(options.get("multiple", False)),
        "directory": bool(options.get("directory", False)),
        "currentFolder": current_folder,
        "currentName": current_name,
        "filters": filters,
        "files": save_files,
    }
    request_path.write_text(json.dumps(payload), encoding="utf-8")
    return request_id, request_path, result_path


def reply_ok(invocation: Gio.DBusMethodInvocation, uris: list[str]) -> None:
    results = {"uris": GLib.Variant("as", uris)}
    invocation.return_value(GLib.Variant("(ua{sv})", (0, results)))


def reply_cancel(invocation: Gio.DBusMethodInvocation) -> None:
    invocation.return_value(GLib.Variant("(ua{sv})", (1, {})))


def reply_error(invocation: Gio.DBusMethodInvocation) -> None:
    invocation.return_value(GLib.Variant("(ua{sv})", (2, {})))


def handle_chooser(mode: str, params, invocation: Gio.DBusMethodInvocation) -> None:
    _handle, _app_id, _parent, title, options_v = params.unpack()
    options = options_dict(options_v)
    request_id, _req_path, result_path = build_request(mode, str(title or ""), options)
    if not launch_picker(request_id):
        reply_error(invocation)
        return

    result = wait_result(result_path)
    shutil.rmtree(result_path.parent, ignore_errors=True)

    if not result:
        reply_error(invocation)
        return
    response = int(result.get("response", 2))
    if response != 0:
        if response == 1:
            reply_cancel(invocation)
        else:
            reply_error(invocation)
        return
    uris = []
    for u in result.get("uris") or []:
        s = str(u)
        if not s:
            continue
        if s.startswith("file:"):
            uris.append(s)
        else:
            uris.append(path_to_uri(s))
    if not uris:
        reply_cancel(invocation)
        return
    reply_ok(invocation, uris)


class FileChooserPortal:
    def __init__(self) -> None:
        self._owner_id = 0
        self._reg_id = 0
        self._node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)

    def run(self) -> int:
        self._owner_id = Gio.bus_own_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameOwnerFlags.NONE,
            self._on_bus_acquired,
            None,
            self._on_name_lost,
        )
        loop = GLib.MainLoop()

        def _stop(*_args):
            loop.quit()

        signal.signal(signal.SIGTERM, _stop)
        signal.signal(signal.SIGINT, _stop)
        loop.run()
        if self._owner_id:
            Gio.bus_unown_name(self._owner_id)
        return 0

    def _on_bus_acquired(self, connection: Gio.DBusConnection, _name: str) -> None:
        self._reg_id = connection.register_object(
            OBJECT_PATH,
            self._node.interfaces[0],
            self._on_method_call,
            self._on_get_property,
            None,
        )

    def _on_name_lost(self, _connection, _name: str) -> None:
        sys.stderr.write("donwaztok-portal: bus name lost\n")
        GLib.MainLoop().quit()

    def _on_get_property(self, _connection, _sender, _path, _iface, prop):
        if prop == "version":
            return GLib.Variant("u", 4)
        return None

    def _on_method_call(
        self,
        _connection,
        _sender,
        _path,
        _iface,
        method: str,
        params: GLib.Variant,
        invocation: Gio.DBusMethodInvocation,
    ) -> None:
        mode = {
            "OpenFile": "open",
            "SaveFile": "save",
            "SaveFiles": "saveFiles",
        }.get(method)
        if not mode:
            invocation.return_error_literal(
                Gio.DBusError.quark(),
                Gio.DBusError.UNKNOWN_METHOD,
                f"Unknown method {method}",
            )
            return
        # Run chooser without blocking the D-Bus dispatch forever in a nested way:
        # schedule after returning from this call stack.
        GLib.idle_add(lambda: (handle_chooser(mode, params, invocation), False)[1])


def main() -> int:
    return FileChooserPortal().run()


if __name__ == "__main__":
    # Quiet unused import warning for quote if tree-shaken; keep available for future.
    _ = quote
    raise SystemExit(main())
