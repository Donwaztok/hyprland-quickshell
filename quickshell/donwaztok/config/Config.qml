pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property AppearanceConfig appearance: DonwaztokConfigStore.topLevel.appearance
    readonly property GeneralConfig general: DonwaztokConfigStore.topLevel.general
    readonly property BackgroundConfig background: DonwaztokConfigStore.topLevel.background
    readonly property BarConfig bar: DonwaztokConfigStore.topLevel.bar
    readonly property BorderConfig border: DonwaztokConfigStore.topLevel.border
    readonly property DashboardConfig dashboard: DonwaztokConfigStore.topLevel.dashboard
    readonly property ControlCenterConfig controlCenter: DonwaztokConfigStore.topLevel.controlCenter
    readonly property LauncherConfig launcher: DonwaztokConfigStore.topLevel.launcher
    readonly property NotifsConfig notifs: DonwaztokConfigStore.topLevel.notifs
    readonly property SessionConfig session: DonwaztokConfigStore.topLevel.session
    readonly property WInfoConfig winfo: DonwaztokConfigStore.topLevel.winfo
    readonly property LockConfig lock: DonwaztokConfigStore.topLevel.lock
    readonly property UtilitiesConfig utilities: DonwaztokConfigStore.topLevel.utilities
    readonly property SidebarConfig sidebar: DonwaztokConfigStore.topLevel.sidebar
    readonly property ServiceConfig services: DonwaztokConfigStore.topLevel.services
    readonly property UserPaths paths: DonwaztokConfigStore.topLevel.paths

    /// M3 / `options` block in donwaztok/config.json (lock blur, AI, search, etc.)
    readonly property var shellOptions: DonwaztokConfigStore.shellOptions

    // Bar UI scale vs 36px design baseline (avoids a separate singleton that would circular-import Config via qs.utils).
    readonly property real barThicknessScale: (bar.sizes.thickness > 0) ? (bar.sizes.thickness / 36) : 1

    readonly property bool loaded: DonwaztokConfigStore.ready

    // Public save function - call this to persist config changes
    function save(): void {
        DonwaztokConfigStore.markTopLevelWritten();
        saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: {
            try {
                DonwaztokConfigStore.writeFullConfig();
            } catch (e) {
                Toaster.toast(qsTr("Failed to serialize config"), e.message, "settings_alert", Toast.Error);
            }
        }
    }

    // One-time move from bar.status.show* / status.drives / tray.hiddenIcons to bar.icons. Runs only while
    // all three lists are empty; the shell icons always sit in one of them afterwards. Reads the raw file,
    // since the old keys are no longer declared (and so no longer written back).
    function migrateBarIcons(text: string): void {
        const icons = bar.icons;
        if (icons.status.length || icons.tray.length || icons.hidden.length)
            return;
        const old = JSON.parse(text)?.bar ?? {};
        const st = old.status ?? {};
        // Defaults of the old keys, for a file that never set them.
        const s = {
            showAudio: st.showAudio ?? false,
            showMicrophone: st.showMicrophone ?? false,
            showKbLayout: st.showKbLayout ?? false,
            showNetwork: st.showNetwork ?? true,
            showBluetooth: st.showBluetooth ?? true,
            drives: st.drives ?? "tray",
            showBattery: st.showBattery ?? true,
            showLockStatus: st.showLockStatus ?? false
        };
        const out = {
            status: [],
            tray: [],
            hidden: []
        };
        // Same order as the status area before the move.
        const legacy = [["lockstatus", s.showLockStatus], ["audio", s.showAudio], ["microphone", s.showMicrophone], ["kblayout", s.showKbLayout], ["drives", null], ["network", s.showNetwork], ["bluetooth", s.showBluetooth], ["battery", s.showBattery]];
        for (const [id, on] of legacy) {
            const group = id === "drives" ? (s.drives in out ? s.drives : "tray") : (on ? "status" : "hidden");
            out[group].push(id);
        }
        for (const app of old.tray?.hiddenIcons ?? [])
            out.hidden.push(`app:${app}`);
        icons.status = out.status;
        icons.tray = out.tray;
        icons.hidden = out.hidden;
        barIconsBackup.running = true;
    }

    // Keeps the pre-migration file (it is not versioned), then saves the new shape.
    Process {
        id: barIconsBackup

        command: ["cp", "-n", DonwaztokConfigStore.filePath, `${DonwaztokConfigStore.filePath}.bak-bar-icons`]
        onExited: root.save()
    }

    Connections {
        target: DonwaztokConfigStore.configFileView

        function onLoaded() {
            try {
                const text = target.text();
                JSON.parse(text);
                root.migrateBarIcons(text);
                const elapsed = DonwaztokConfigStore.configLoadElapsed.elapsedMs();
                const ad = DonwaztokConfigStore.topLevel;
                if (ad.utilities.toasts.configLoaded && !DonwaztokConfigStore.topLevelWriteCooldown && elapsed > 0) {
                    Toaster.toast(qsTr("Config loaded"), qsTr("Config loaded in %1ms").arg(elapsed), "rule_settings");
                } else if (ad.utilities.toasts.configLoaded && DonwaztokConfigStore.topLevelWriteCooldown && elapsed > 0) {
                    Toaster.toast(qsTr("Config saved"), qsTr("Config reloaded in %1ms").arg(elapsed), "rule_settings");
                }
            } catch (e) {
                Toaster.toast(qsTr("Failed to load config"), e.message, "settings_alert", Toast.Error);
            }
        }

        function onLoadFailed(err) {
            if (err !== FileViewError.FileNotFound)
                Toaster.toast(qsTr("Failed to read config file"), FileViewError.toString(err), "settings_alert", Toast.Warning);
        }

        function onSaveFailed(err) {
            Toaster.toast(qsTr("Failed to save config"), FileViewError.toString(err), "settings_alert", Toast.Error);
        }
    }
}
