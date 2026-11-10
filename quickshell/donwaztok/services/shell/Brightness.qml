pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.components.misc
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    signal brightnessChanged() // user-driven change only, for the OSD

    property list<var> ddcMonitors: []
    readonly property var ddcMonitorMap: {
        const map = {};
        for (const m of ddcMonitors)
            map[m.connector] = m;
        return map;
    }
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false
    property bool hasBacklight: false
    readonly property bool available: appleDisplayPresent || ddcMonitors.length > 0 || hasBacklight

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    function getMonitor(query: string): var {
        if (query === "active") {
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.focused);
        }

        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData.model === model);
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData.serialNumber === serial);
        }

        if (query.startsWith("id:")) {
            const id = parseInt(query.slice(3), 10);
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.id === id);
        }

        return monitors.find(m => m.modelData.name === query);
    }

    function stepBrightness(delta: real): void {
        const monitor = getMonitor("active");
        if (!monitor?.available)
            return;
        monitor.setBrightness(monitor.brightness + delta);
    }

    function increaseBrightness(): void {
        stepBrightness(Config.services.brightnessIncrement);
    }

    function decreaseBrightness(): void {
        stepBrightness(-Config.services.brightnessIncrement);
    }

    onHasBacklightChanged: {
        if (!hasBacklight)
            return;
        for (const m of monitors) {
            if (!m.isDdc && !m.isAppleDisplay)
                m.initBrightness();
        }
    }

    // True while `ddcutil detect` holds the I2C buses; writes wait for it (a write on a busy bus fails silently).
    property bool detecting: false

    onMonitorsChanged: {
        ddcMonitors = [];
        detecting = true;
        ddcProc.running = true;
    }

    Variants {
        id: variants

        model: Quickshell.screens // Don't respect excluded screens cause ipc

        Monitor {}
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.hasBacklight = text.trim().length > 0
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "asdbctl get"] // To avoid warnings if asdbctl is not installed
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        onExited: {
            root.detecting = false;
            for (const m of root.monitors) {
                if (m.pendingDdc < 0 || m.ddcBusy)
                    continue;
                const value = m.pendingDdc;
                m.pendingDdc = -1;
                m.writeDdc(value);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.ddcMonitors = text.trim().split("\n\n").filter(d => d.startsWith("Display ")).map(d => ({
                        busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)[1],
                        connector: d.match(/DRM connector:\s+(.*)/)[1].replace(/^card\d+-/, "") // strip "card1-"
                    }))
        }
    }

    CustomShortcut {
        name: "brightnessUp"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    CustomShortcut {
        name: "brightnessDown"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }

    IpcHandler {
        target: "brightness"

        function increment(): void {
            root.increaseBrightness();
        }

        function decrement(): void {
            root.decreaseBrightness();
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property var ddcInfo: root.ddcMonitorMap[modelData?.name] ?? null
        readonly property bool isDdc: ddcInfo !== null
        readonly property string busNum: ddcInfo?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        readonly property bool available: isAppleDisplay || isDdc || root.hasBacklight
        property real brightness
        // Last DDC value asked for while a write was still running (-1: none).
        property int pendingDdc: -1
        // Own flag: Process.running only turns true once the process has actually started.
        property bool ddcBusy: false

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (monitor.isAppleDisplay) {
                        const val = parseInt(text.trim());
                        monitor.brightness = val / 101;
                    } else {
                        const [, , , cur, max] = text.split(" ");
                        monitor.brightness = parseInt(cur) / parseInt(max);
                    }
                }
            }
        }

        // One ddcutil write at a time: a write takes ~0.5 s and a second one on a busy bus fails silently.
        readonly property Process writeProc: Process {
            onExited: (code, status) => {
                monitor.ddcBusy = false;
                if (monitor.pendingDdc < 0)
                    return;
                const value = monitor.pendingDdc;
                monitor.pendingDdc = -1;
                Qt.callLater(() => monitor.writeDdc(value));
            }
        }

        function writeDdc(value: int): void {
            if (ddcBusy || root.detecting) {
                pendingDdc = value;
                return;
            }
            ddcBusy = true;
            // Qualified: a bare `ddcProc` would resolve to the root's `ddcutil detect` process by id.
            monitor.writeProc.command = ["ddcutil", "-b", busNum, "setvcp", "10", String(value)];
            monitor.writeProc.running = true;
        }

        function setBrightness(value: real): void {
            if (!available)
                return;

            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            // Shown at once; the hardware catches up (DDC writes are serialized in writeDdc).
            brightness = value;
            root.brightnessChanged();

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc)
                writeDdc(rounded);
            else if (root.hasBacklight)
                Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
        }

        function initBrightness(): void {
            if (isAppleDisplay)
                initProc.command = ["asdbctl", "get"];
            else if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else if (root.hasBacklight)
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];
            else
                return;

            initProc.running = true;
        }

        onBusNumChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
