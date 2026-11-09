#!/usr/bin/env python3
"""Self-check for agent.py: python3 agent_test.py

Exports the agent on the session bus (the system bus does not let a user call it) and plays
BlueZ's part: each call must reach the shell as a JSON request and return the shell's answer.
"""
import threading

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

import agent

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
sent = []
agent.emit = lambda **msg: sent.append(msg)
obj = agent.Agent(bus)
DEVICE = dbus.ObjectPath("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF")


def call(method, *args):
    """Calls the agent from a thread, answers like the shell would, returns (result, error)."""
    out = {}

    def run():
        proxy = dbus.SessionBus(private=True).get_object(bus.get_unique_name(), agent.AGENT_PATH)
        try:
            out["result"] = getattr(proxy, method)(*args, dbus_interface="org.bluez.Agent1")
        except dbus.DBusException as e:
            out["error"] = e.get_dbus_name()

    t = threading.Thread(target=run)
    t.start()
    ctx = GLib.MainContext.default()
    while t.is_alive():
        ctx.iteration(False)
        t.join(0.01)
    return out.get("result"), out.get("error")


def answering(reply):
    """Answers the next request the agent emits with reply (merged with its id)."""
    def tick():
        if sent and "id" in sent[-1] and obj.pending:
            obj.answer({"id": sent[-1]["id"], **reply})
            return False
        return True
    GLib.timeout_add(5, tick)


answering({"ok": True})
result, error = call("RequestConfirmation", DEVICE, dbus.UInt32(42))
assert error is None, error
assert sent[-1]["type"] == "confirm" and sent[-1]["code"] == "000042", sent[-1]
assert sent[-1]["device"] == "AA:BB:CC:DD:EE:FF", sent[-1]  # no BlueZ here: falls back to the address

answering({"ok": True, "value": "123456"})
result, error = call("RequestPasskey", DEVICE)
assert error is None and int(result) == 123456, (result, error)

answering({"ok": True, "value": "12a"})
result, error = call("RequestPasskey", DEVICE)
assert error == "org.bluez.Error.Rejected", error

answering({"ok": True, "value": "0000"})
result, error = call("RequestPinCode", DEVICE)
assert error is None and str(result) == "0000", (result, error)

answering({"ok": False})
result, error = call("AuthorizeService", DEVICE, "0000110b-0000-1000-8000-00805f9b34fb")
assert error == "org.bluez.Error.Rejected", error
assert sent[-1]["type"] == "service"

call("DisplayPasskey", DEVICE, dbus.UInt32(7), dbus.UInt16(2))
assert sent[-1] == {"type": "display", "device": "AA:BB:CC:DD:EE:FF", "code": "000007", "entered": 2}

# Cancel fails what is still waiting and tells the shell to close the dialog.
waiting = {}
obj.ask("confirm", DEVICE, lambda: None, lambda e: waiting.setdefault("error", e.get_dbus_name()))
call("Cancel")
assert waiting["error"] == "org.bluez.Error.Canceled" and not obj.pending
assert sent[-1] == {"type": "cancel"}

print("agent ok")
