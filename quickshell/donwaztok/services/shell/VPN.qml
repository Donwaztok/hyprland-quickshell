pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.utils

Singleton {
    id: root

    property bool connected: false
    property string fvpnPendingAction: "" // "" | "connect"
    property bool fvpnSystemReady: false

    readonly property bool connecting: connectProc.running || disconnectProc.running || fvpnEnsureProc.running
    readonly property bool enabled: Config.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false)
    readonly property var providerInput: {
        const enabledProvider = Config.utilities.vpn.provider.find(p => typeof p === "object" ? (p.enabled === true) : false);
        return enabledProvider || "wireguard";
    }
    readonly property bool isCustomProvider: typeof providerInput === "object"
    readonly property string providerName: isCustomProvider ? (providerInput.name || "custom") : String(providerInput)
    readonly property string interfaceName: isCustomProvider ? (providerInput.interface || "") : ""
    readonly property var currentConfig: {
        const name = providerName;
        const iface = interfaceName;
        const defaults = getBuiltinDefaults(name, iface);

        if (isCustomProvider) {
            const custom = providerInput;
            return {
                connectCmd: custom.connectCmd || defaults.connectCmd,
                disconnectCmd: custom.disconnectCmd || defaults.disconnectCmd,
                interface: custom.interface || defaults.interface,
                displayName: custom.displayName || defaults.displayName
            };
        }

        return defaults;
    }

    readonly property string fvpnPath: Quickshell.shellPath("scripts/vpn/fvpn")

    function getBuiltinDefaults(name, iface) {
        const builtins = {
            "wireguard": {
                connectCmd: ["pkexec", "wg-quick", "up", iface],
                disconnectCmd: ["pkexec", "wg-quick", "down", iface],
                interface: iface,
                displayName: iface
            },
            "warp": {
                connectCmd: ["warp-cli", "connect"],
                disconnectCmd: ["warp-cli", "disconnect"],
                interface: "CloudflareWARP",
                displayName: "Warp"
            },
            "netbird": {
                connectCmd: ["netbird", "up"],
                disconnectCmd: ["netbird", "down"],
                interface: "wt0",
                displayName: "NetBird"
            },
            "tailscale": {
                connectCmd: ["tailscale", "up"],
                disconnectCmd: ["tailscale", "down"],
                interface: "tailscale0",
                displayName: "Tailscale"
            },
            "fastestvpn": {
                connectCmd: [root.fvpnPath, "up"],
                disconnectCmd: [root.fvpnPath, "down"],
                interface: iface || "tun0",
                displayName: "FastestVPN"
            }
        };

        return builtins[name] || {
            connectCmd: [name, "up"],
            disconnectCmd: [name, "down"],
            interface: iface || name,
            displayName: name
        };
    }

    function connect(): void {
        if (!connected && !connecting && root.currentConfig && root.currentConfig.connectCmd) {
            connectProc.exec(root.currentConfig.connectCmd);
        }
    }

    function disconnect(): void {
        if (connected && !connecting && root.currentConfig && root.currentConfig.disconnectCmd) {
            disconnectProc.exec(root.currentConfig.disconnectCmd);
        }
    }

    function toggle(): void {
        if (connected) {
            disconnect();
        } else {
            connect();
        }
    }

    // Survives Control Center close: one-time admin setup, then connect.
    function ensureSystemThenConnect(closeSettingsFn): void {
        root.fvpnPendingAction = "connect";
        if (typeof closeSettingsFn === "function")
            closeSettingsFn();
        fvpnEnsureDelay.restart();
    }

    function startFvpnRank(mode): void {
        fvpnRankStartProc.exec([root.fvpnPath, "rank-start", mode, "udp"]);
    }

    function checkStatus(): void {
        if (root.enabled) {
            statusProc.running = true;
        }
    }

    onConnectedChanged: {
        if (!Config.utilities.toasts.vpnChanged)
            return;

        const displayName = root.currentConfig ? (root.currentConfig.displayName || "VPN") : "VPN";
        if (connected) {
            Toaster.toast(qsTr("VPN connected"), qsTr("Connected to %1").arg(displayName), "vpn_key");
        } else {
            Toaster.toast(qsTr("VPN disconnected"), qsTr("Disconnected from %1").arg(displayName), "vpn_key_off");
        }
    }

    Component.onCompleted: root.enabled && statusCheckTimer.start()

    Process {
        id: nmMonitor

        running: root.enabled
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: statusCheckTimer.restart()
        }
    }

    Process {
        id: statusProc

        command: ["ip", "link", "show"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                const iface = root.currentConfig ? root.currentConfig.interface : "";
                root.connected = iface && text.includes(iface + ":");
            }
        }
    }

    Process {
        id: connectProc

        onExited: statusCheckTimer.start()
        stderr: StdioCollector {
            onStreamFinished: {
                const error = text.trim();
                if (error && !error.includes("[#]") && !error.includes("already exists")) {
                    console.warn("VPN connection error:", error);
                } else if (error.includes("already exists")) {
                    root.connected = true;
                }
            }
        }
    }

    Process {
        id: disconnectProc

        onExited: statusCheckTimer.start()
        stderr: StdioCollector {
            onStreamFinished: {
                const error = text.trim();
                if (error && !error.includes("[#]")) {
                    console.warn("VPN disconnection error:", error);
                }
            }
        }
    }

    Timer {
        id: statusCheckTimer

        interval: 500
        onTriggered: root.checkStatus()
    }

    Timer {
        id: fvpnEnsureDelay
        interval: 400
        repeat: false
        onTriggered: fvpnEnsureProc.exec([root.fvpnPath, "ensure"])
    }

    Process {
        id: fvpnEnsureProc
        onExited: code => {
            const action = root.fvpnPendingAction;
            root.fvpnPendingAction = "";
            if (code === 0) {
                root.fvpnSystemReady = true;
                Toaster.toast(qsTr("VPN ready"), qsTr("OpenVPN permission saved — no more admin for Connect."), "vpn_key");
                if (action === "connect")
                    root.connect();
            } else {
                Toaster.toast(qsTr("Setup cancelled"), qsTr("Approve the password dialog to finish VPN setup."), "error");
            }
        }
    }

    Process {
        id: fvpnRankStartProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text.trim());
                    if (res && res.ok === false)
                        Toaster.toast(qsTr("Could not start scan"), res.error || "", "error");
                } catch (e) {}
            }
        }
    }
}
