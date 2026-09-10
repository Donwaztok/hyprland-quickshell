import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: root

    property HyprDevices devices: dev
    property QtObject options: opts

    property bool _devicesPending: false
    property int debounceMs: 60

    function refreshDevices() {
        soonTimer.restart();
    }

    function refreshDevicesNow() {
        if (devicesProc.running) {
            _devicesPending = true;
            return;
        }
        devicesProc.running = true;
    }

    function batchMessage(arr) {
        if (!arr || arr.length === 0)
            return;

        for (let i = 0; i < arr.length; i++) {
            const msg = arr[i];
            if (!msg)
                continue;

            const m = String(msg).match(/^(\S+)\s+([\s\S]+)$/);
            if (m)
                Quickshell.execDetached(["hyprctl", m[1], m[2]]);
            else
                Quickshell.execDetached(["hyprctl", String(msg)]);
        }
    }

    function refreshOptions() {}

    Component.onCompleted: refreshDevicesNow()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                root.refreshDevices();
        }
    }

    Timer {
        id: soonTimer
        interval: root.debounceMs
        repeat: false
        onTriggered: root.refreshDevicesNow()
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.devices.updateFromIpc(JSON.parse(text));
                } catch (e) {
                    console.warn("[HyprExtras] Failed to parse devices:", e);
                }
            }
        }
        onExited: {
            if (root._devicesPending) {
                root._devicesPending = false;
                Qt.callLater(() => root.refreshDevicesNow());
            }
        }
    }

    HyprDevices {
        id: dev
    }

    QtObject {
        id: opts
    }
}
