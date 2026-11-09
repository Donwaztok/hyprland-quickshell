#!/usr/bin/env python3
"""BlueZ pairing agent for the shell (replaces blueman-applet's).

Requests go out as JSON lines on stdout ({"type", "id", "device", ...}); the shell answers
on stdin with {"id": n, "ok": bool, "value": str}. Types that need an answer: pin, passkey,
confirm, authorize, service. Notices without an id: display, cancel, done, ready.
"""

import json
import os
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/donwaztok/bluetooth_agent"
CAPABILITY = "KeyboardDisplay"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


def emit(**msg):
    print(json.dumps(msg), flush=True)


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus
        self.pending = {}  # id -> (kind, reply, error)
        self.seq = 0

    def device_name(self, path):
        try:
            props = dbus.Interface(self.bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
            return str(props.Get("org.bluez.Device1", "Alias"))
        except dbus.DBusException:
            return str(path).rsplit("/", 1)[-1].removeprefix("dev_").replace("_", ":")

    def ask(self, kind, device, reply, error, **extra):
        self.seq += 1
        self.pending[self.seq] = (kind, reply, error)
        emit(type=kind, id=self.seq, device=self.device_name(device), **extra)

    def answer(self, msg):
        entry = self.pending.pop(msg.get("id"), None)
        if entry is None:
            return
        kind, reply, error = entry
        if not msg.get("ok"):
            error(Rejected("Rejected by user"))
            return
        value = str(msg.get("value", "")).strip()
        if kind == "pin":
            reply(dbus.String(value))
        elif kind == "passkey":
            if not value.isdigit():
                error(Rejected("Passkey must be a number"))
                return
            reply(dbus.UInt32(int(value)))
        else:
            reply()

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s",
                         async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        self.ask("pin", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u",
                         async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        self.ask("passkey", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit(type="display", device=self.device_name(device), code=f"{passkey:06d}", entered=int(entered))

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit(type="display", device=self.device_name(device), code=str(pincode), entered=0)

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.ask("confirm", device, reply, error, code=f"{passkey:06d}")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        self.ask("authorize", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="",
                         async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid, reply, error):
        self.ask("service", device, reply, error, uuid=str(uuid))

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        for _kind, _reply, error in self.pending.values():
            error(Canceled("Canceled by remote"))
        self.pending.clear()
        emit(type="cancel")


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus)
    loop = GLib.MainLoop()

    def register(owner):
        # Runs at start and whenever bluetoothd (re)appears; its agents die with it.
        if not owner:
            return
        try:
            manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
            manager.RegisterAgent(AGENT_PATH, CAPABILITY)
            manager.RequestDefaultAgent(AGENT_PATH)
            emit(type="ready", bus=bus.get_unique_name())
        except dbus.DBusException as e:
            print(f"bluetooth agent: register failed: {e}", file=sys.stderr, flush=True)

    def on_props(iface, changed, _invalidated, path=None):
        # Closes the "type this code" notice once the device is paired.
        if iface == "org.bluez.Device1" and changed.get("Paired"):
            emit(type="done", device=agent.device_name(path))

    buf = b""

    def on_stdin(fd, _condition):
        nonlocal buf
        chunk = os.read(fd, 4096)
        if not chunk:  # the shell went away
            loop.quit()
            return False
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for line in lines:
            try:
                agent.answer(json.loads(line))
            except (ValueError, AttributeError):
                pass
        return True

    bus.watch_name_owner("org.bluez", register)
    bus.add_signal_receiver(on_props, "PropertiesChanged", "org.freedesktop.DBus.Properties",
                            path_keyword="path")
    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    loop.run()


if __name__ == "__main__":
    main()
