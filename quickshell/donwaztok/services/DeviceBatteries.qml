pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// Peripheral batteries from UPower (Logitech HID++), BlueZ, and USB dongles
// that connect without publishing a charge level.
Singleton {
    id: root

    property var extraDevices: []
    property var alertLevels: ({})
    readonly property int lowLevel: Config.options?.battery?.low ?? 20
    readonly property int criticalLevel: Config.options?.battery?.critical ?? 5
    readonly property bool soundEnabled: Config.options?.sounds?.battery ?? false
    readonly property bool configReady: Config.ready

    readonly property var devices: {
        const merged = [];
        const seenNames = {};

        const upowerDevices = UPower.devices?.values ?? [];
        for (let i = 0; i < upowerDevices.length; i++) {
            const dev = upowerDevices[i];
            if (!dev || dev.isLaptopBattery || dev.type === UPowerDeviceType.LinePower || dev.type === UPowerDeviceType.Ups)
                continue;

            const model = (dev.model || "").trim();
            const percent = root.asPercent(dev.percentage);
            if (!model && percent < 0)
                continue;

            const kind = root.kindForType(dev.type);
            const name = model || kind;
            const entry = {
                key: dev.nativePath || name,
                name: name,
                kind: kind,
                icon: root.iconForKind(kind),
                percent: percent,
                state: root.stateName(dev.state),
                detail: ""
            };
            merged.push(entry);
            seenNames[root.normalizeName(name)] = true;
        }

        const bluetoothDevices = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < bluetoothDevices.length; i++) {
            const dev = bluetoothDevices[i];
            if (!dev || !dev.connected)
                continue;
            const name = (dev.name || "").trim();
            if (!name || seenNames[root.normalizeName(name)])
                continue;
            if (!dev.batteryAvailable && root.kindForName(name) === "other")
                continue;

            const kind = root.kindForName(name);
            merged.push({
                key: dev.dbusPath || `bt-${name}`,
                name: name,
                kind: kind,
                icon: root.iconForKind(kind),
                percent: dev.batteryAvailable ? root.asPercent(dev.battery) : -1,
                state: "unknown",
                detail: dev.batteryAvailable ? "" : qsTr("Bluetooth is not reporting charge")
            });
            seenNames[root.normalizeName(name)] = true;
        }

        const extras = root.extraDevices || [];
        for (let i = 0; i < extras.length; i++) {
            const dev = extras[i];
            if (!dev || seenNames[root.normalizeName(dev.name || "")])
                continue;
            const kind = dev.kind || "other";
            merged.push({
                key: dev.key || dev.name,
                name: dev.name || kind,
                kind: kind,
                icon: root.iconForKind(kind),
                percent: root.asPercent(dev.percent),
                state: dev.state || "unknown",
                detail: dev.detail || ""
            });
        }

        merged.sort((a, b) => {
            const ap = a.percent < 0 ? 101 : a.percent;
            const bp = b.percent < 0 ? 101 : b.percent;
            return ap - bp || a.name.localeCompare(b.name);
        });
        return merged;
    }

    readonly property int lowestPercent: {
        let lowest = -1;
        const list = root.devices;
        for (let i = 0; i < list.length; i++) {
            const percent = list[i].percent;
            if (percent < 0)
                continue;
            if (lowest < 0 || percent < lowest)
                lowest = percent;
        }
        return lowest;
    }

    function asPercent(value): int {
        if (value === null || value === undefined || value === "")
            return -1;
        const number = Number(value);
        if (!Number.isFinite(number) || number < 0)
            return -1;
        if (number <= 1)
            return Math.round(number * 100);
        return Math.round(Math.min(number, 100));
    }

    function normalizeName(name: string): string {
        return name.toLowerCase().replace(/[^a-z0-9]+/g, "");
    }

    function kindForType(type): string {
        if (type === UPowerDeviceType.Mouse)
            return "mouse";
        if (type === UPowerDeviceType.Keyboard)
            return "keyboard";
        if (type === UPowerDeviceType.Headset || type === UPowerDeviceType.Headphones || type === UPowerDeviceType.Speakers || type === UPowerDeviceType.OtherAudio)
            return "headset";
        if (type === UPowerDeviceType.GamingInput)
            return "controller";
        return "other";
    }

    function kindForName(name: string): string {
        const lowered = name.toLowerCase();
        if (lowered.includes("8bit") || lowered.includes("controller") || lowered.includes("gamepad"))
            return "controller";
        if (lowered.includes("mouse"))
            return "mouse";
        if (lowered.includes("keyboard") || lowered.includes("pro x 60"))
            return "keyboard";
        if (lowered.includes("hyperx") || lowered.includes("stinger") || lowered.includes("headset") || lowered.includes("headphone") || lowered.includes("buds") || lowered.includes("fone"))
            return "headset";
        return "other";
    }

    function iconForKind(kind: string): string {
        if (kind === "mouse")
            return "mouse";
        if (kind === "keyboard")
            return "keyboard";
        if (kind === "headset")
            return "headphones";
        if (kind === "controller")
            return "sports_esports";
        return "battery_std";
    }

    function stateName(state): string {
        if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge)
            return "charging";
        if (state === UPowerDeviceState.FullyCharged)
            return "full";
        if (state === UPowerDeviceState.Discharging || state === UPowerDeviceState.Empty)
            return "discharging";
        return "unknown";
    }

    function refresh(): void {
        if (!probe.running)
            probe.running = true;
    }

    function evaluateAlerts(): void {
        if (!root.configReady)
            return;

        const previous = root.alertLevels || {};
        const next = {};
        const list = root.devices;
        for (let i = 0; i < list.length; i++) {
            const device = list[i];
            const percent = device.percent;
            next[device.key] = percent;
            if (percent < 0 || device.state === "charging" || device.state === "full")
                continue;

            const prev = Object.prototype.hasOwnProperty.call(previous, device.key) ? previous[device.key] : 101;
            let crossed = null;
            if (percent <= root.lowLevel && prev > root.lowLevel) {
                crossed = {
                    title: qsTr("Low battery"),
                    urgency: "normal"
                };
            }
            if (percent <= root.criticalLevel && prev > root.criticalLevel) {
                crossed = {
                    title: qsTr("Critical battery"),
                    urgency: "critical"
                };
            }
            if (crossed)
                root.notify(device, crossed);
        }
        root.alertLevels = next;
    }

    function notify(device, level): void {
        Quickshell.execDetached([
            "notify-send",
            level.title,
            qsTr("%1 is at %2%").arg(device.name).arg(device.percent),
            "-a", "Shell",
            "-u", level.urgency,
            "-h", `string:x-canonical-private-synchronous:qs-device-battery-${device.key}`,
            "--hint=int:transient:1"
        ]);
        if (root.soundEnabled)
            Audio.playSystemSound(level.urgency === "critical" ? "suspend-error" : "dialog-warning");
    }

    onConfigReadyChanged: {
        if (root.configReady)
            root.evaluateAlerts();
    }

    onDevicesChanged: root.evaluateAlerts()

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        command: ["python3", Quickshell.shellPath("scripts/device-batteries.py")]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(line => line.length > 0);
                const raw = lines.length > 0 ? lines[lines.length - 1] : "";
                if (!raw) {
                    root.extraDevices = [];
                    return;
                }
                try {
                    const parsed = JSON.parse(raw);
                    root.extraDevices = Array.isArray(parsed.devices) ? parsed.devices : [];
                } catch (error) {
                    root.extraDevices = [];
                }
            }
        }
    }
}
