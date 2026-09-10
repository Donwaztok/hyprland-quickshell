pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DeviceDetails {
    id: root

    required property Session session
    readonly property var vpnProvider: root.session.vpn.active
    readonly property bool providerEnabled: {
        if (!vpnProvider || vpnProvider.index === undefined)
            return false;
        const provider = Config.utilities.vpn.provider[vpnProvider.index];
        return provider && typeof provider === "object" && provider.enabled === true;
    }

    readonly property bool isFastestVpn: root.vpnProvider?.name === "fastestvpn"
    property string fvpnDefault: "brazil-udp"
    property string fvpnReadyText: qsTr("Checking…")
    property bool fvpnHasAuth: false
    property bool fvpnHasConfigs: false
    property bool fvpnHasCaps: false
    property var fvpnServers: []

    property string fvpnViewMode: "latency" // latency | speed
    property string fvpnJobStatus: "idle"
    property string fvpnJobMode: ""
    property real fvpnJobFraction: 0
    property string fvpnJobProgressText: ""
    property var fvpnLatencyResults: []
    property var fvpnSpeedResults: []
    property var fvpnLatencyMeta: ({})
    property var fvpnSpeedMeta: ({})

    readonly property bool fvpnJobRunning: fvpnJobStatus === "running"
    readonly property var fvpnRankResults: fvpnViewMode === "speed" ? fvpnSpeedResults : fvpnLatencyResults

    readonly property string fvpnCacheDir: {
        const home = Quickshell.env("HOME") || "";
        return `${home}/.cache/donwaztok/fvpn-cache`;
    }
    readonly property string fvpnJobPath: `${fvpnCacheDir}/job.json`
    readonly property string fvpnLatencyPath: `${fvpnCacheDir}/latency.json`
    readonly property string fvpnSpeedPath: `${fvpnCacheDir}/speed.json`

    function cloneProvider(p, overrides) {
        if (typeof p !== "object")
            return p;
        overrides = overrides || {};
        const out = {};
        for (const key of Object.keys(p))
            out[key] = p[key];
        for (const key of Object.keys(overrides))
            out[key] = overrides[key];
        return out;
    }

    function formatMbps(v) {
        if (v === null || v === undefined || v < 0)
            return "—";
        return qsTr("%1 Mbps").arg(Number(v).toFixed(1));
    }

    function formatLatency(v) {
        if (v === null || v === undefined)
            return "—";
        if (Number(v) >= 9000)
            return qsTr("timeout");
        return qsTr("%1 ms").arg(Number(v).toFixed(1));
    }

    function formatAge(sec) {
        if (sec === null || sec === undefined)
            return qsTr("never");
        const s = Number(sec);
        if (s < 60)
            return qsTr("%1s ago").arg(s);
        if (s < 3600)
            return qsTr("%1 min ago").arg(Math.floor(s / 60));
        if (s < 86400)
            return qsTr("%1h ago").arg(Math.floor(s / 3600));
        return qsTr("%1d ago").arg(Math.floor(s / 86400));
    }

    function formatDuration(sec) {
        if (sec === null || sec === undefined)
            return "";
        const s = Number(sec);
        if (s < 60)
            return qsTr("%1s").arg(s);
        return qsTr("%1 min").arg(Math.max(1, Math.round(s / 60)));
    }

    function cacheHint(meta) {
        const age = meta?.ageSec;
        if (age === null || age === undefined)
            return qsTr("No cache yet");
        const ageText = root.formatAge(age);
        const dur = root.formatDuration(meta?.durationSec);
        const when = meta?.finishedAt || meta?.updatedAt || "";
        let text = dur ? qsTr("Last scan %1 · took %2").arg(ageText).arg(dur) : qsTr("Last scan %1").arg(ageText);
        if (when)
            text += qsTr(" (%1)").arg(when);
        if (age > 6 * 3600)
            text += qsTr(" · consider a new scan");
        return text;
    }

    function applyRankData(data) {
        if (!data)
            return;

        const job = data.job || {
            status: data.status || "idle",
            mode: data.mode || "",
            progress: data.progress || null
        };
        root.fvpnJobStatus = job.status || "idle";
        root.fvpnJobMode = job.mode || "";

        const p = job.progress;
        if (root.fvpnJobRunning && p && p.total > 0) {
            root.fvpnJobFraction = Math.min(1, Math.max(0, (p.current || 0) / p.total));
            let phase = qsTr("latency");
            if (p.phase === "speed")
                phase = qsTr("download/upload");
            else if (p.phase === "auth")
                phase = qsTr("waiting for admin approval");
            else if (p.phase === "starting")
                phase = qsTr("starting");
            else if (p.phase === "latency")
                phase = qsTr("latency");
            root.fvpnJobProgressText = qsTr("Running %1… %2/%3 — %4").arg(phase).arg(p.current || 0).arg(p.total || 0).arg(p.server || "");
        } else if (root.fvpnJobRunning && p && p.phase === "auth") {
            root.fvpnJobFraction = 0;
            root.fvpnJobProgressText = qsTr("Waiting for one-time OpenVPN permission…");
        } else if (root.fvpnJobRunning) {
            root.fvpnJobFraction = 0;
            root.fvpnJobProgressText = qsTr("Starting…");
        } else if (root.fvpnJobStatus === "error") {
            root.fvpnJobFraction = 0;
            root.fvpnJobProgressText = job.error || qsTr("Error");
        } else if (root.fvpnJobStatus === "stopped") {
            root.fvpnJobFraction = 0;
            root.fvpnJobProgressText = qsTr("Stopped");
        } else {
            root.fvpnJobFraction = root.fvpnJobStatus === "done" ? 1 : 0;
            root.fvpnJobProgressText = "";
        }

        const latency = data.latency || {
            results: data.mode === "latency" ? (data.results || []) : [],
            ageSec: null
        };
        const speed = data.speed || {
            results: data.mode === "speed" ? (data.results || []) : [],
            ageSec: null
        };
        root.fvpnLatencyMeta = latency;
        root.fvpnSpeedMeta = speed;
        root.fvpnLatencyResults = latency.results || [];
        root.fvpnSpeedResults = speed.results || [];

        if (root.fvpnJobRunning && root.fvpnJobMode)
            root.fvpnViewMode = root.fvpnJobMode;
        else if (!root.fvpnJobRunning && (data.view === "latency" || data.view === "speed")) {
            // Only auto-pick view when idle and user hasn't chosen yet this session.
            if (!root.fvpnViewMode)
                root.fvpnViewMode = data.view;
        }
    }

    function refreshFvpnReady() {
        if (!root.isFastestVpn)
            return;
        fvpnReadyProc.running = true;
        fvpnListProc.running = true;
        fvpnRankStatusProc.running = true;
    }

    function closeForPolkit() {
        // Polkit dialog appears behind the control center focus grab.
        if (root.session && root.session.root)
            root.session.root.close();
    }

    function setDefaultServer(server) {
        if (!server)
            return;
        root.fvpnDefault = server;
        fvpnDefaultProc.exec([VPN.fvpnPath, "default", server]);
    }

    function startRank(mode) {
        // Never close settings for scans — worker writes cache so progress survives reopen.
        // Speed phase asks for admin once from the background job if needed.
        root.fvpnViewMode = mode;
        root.fvpnJobStatus = "running";
        root.fvpnJobMode = mode;
        root.fvpnJobFraction = 0;
        root.fvpnJobProgressText = qsTr("Starting…");
        rankPollTimer.interval = 500;
        rankPollTimer.start();
        VPN.startFvpnRank(mode);
    }

    onIsFastestVpnChanged: {
        root.refreshFvpnReady();
        if (root.isFastestVpn) {
            rankPollTimer.interval = 1000;
            rankPollTimer.start();
        } else {
            rankPollTimer.stop();
        }
    }
    Component.onCompleted: {
        root.refreshFvpnReady();
        if (root.isFastestVpn) {
            rankPollTimer.interval = 1000;
            rankPollTimer.start();
        }
    }

    device: vpnProvider

    headerComponent: Component {
        ConnectionHeader {
            icon: "vpn_key"
            title: root.vpnProvider?.displayName ?? qsTr("Unknown")
        }
    }

    Timer {
        id: rankPollTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (!root.isFastestVpn) {
                stop();
                return;
            }
            fvpnRankStatusProc.running = true;
            interval = root.fvpnJobRunning ? 500 : 5000;
        }
    }

    FileView {
        id: jobFileView
        path: root.fvpnJobPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: fvpnRankStatusProc.running = true
    }

    FileView {
        id: latencyFileView
        path: root.fvpnLatencyPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: fvpnRankStatusProc.running = true
    }

    FileView {
        id: speedFileView
        path: root.fvpnSpeedPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: fvpnRankStatusProc.running = true
    }

    Process {
        id: fvpnReadyProc
        command: [VPN.fvpnPath, "ready"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    root.fvpnHasAuth = !!data.auth;
                    root.fvpnHasConfigs = !!data.configs;
                    root.fvpnHasCaps = !!data.caps;
                    root.fvpnDefault = data.default || "brazil-udp";
                    const parts = [];
                    parts.push(data.openvpn ? qsTr("OpenVPN OK") : qsTr("OpenVPN missing"));
                    parts.push(data.configs ? qsTr("Configs OK") : qsTr("Configs missing"));
                    parts.push(data.auth ? qsTr("Credentials OK") : qsTr("Credentials missing"));
                    parts.push(data.caps ? qsTr("Ready") : qsTr("First Connect asks password once"));
                    root.fvpnReadyText = parts.join(" · ");
                } catch (e) {
                    root.fvpnReadyText = qsTr("Could not read FastestVPN status");
                }
            }
        }
    }

    Process {
        id: fvpnListProc
        command: [VPN.fvpnPath, "list", "udp"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fvpnServers = text.trim().split("\n").filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: fvpnRankStatusProc
        command: [VPN.fvpnPath, "rank-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyRankData(JSON.parse(text.trim()));
                } catch (e) {}
            }
        }
    }

    Process {
        id: fvpnSetupProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out)
                    console.log("fvpn setup:", out);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err)
                    console.warn("fvpn setup error:", err);
            }
        }
        onExited: code => {
            root.refreshFvpnReady();
            if (code === 0)
                Toaster.toast(qsTr("Credentials saved"), qsTr("Stored in your user config (no admin password needed)."), "vpn_key");
            else
                Toaster.toast(qsTr("Could not save credentials"), qsTr("Check the username/password and try again."), "error");
        }
    }

    Process {
        id: fvpnDefaultProc
        onExited: root.refreshFvpnReady()
    }

    Process {
        id: fvpnRankStopProc
        onExited: fvpnRankStatusProc.running = true
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SectionHeader {
                    title: qsTr("Connection status")
                    description: qsTr("VPN connection settings")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("Enable this provider")
                        checked: root.providerEnabled
                        toggle.onToggled: {
                            if (!root.vpnProvider)
                                return;
                            const providers = [];
                            const index = root.vpnProvider.index;

                            for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                const p = Config.utilities.vpn.provider[i];
                                if (typeof p === "object") {
                                    if (checked) {
                                        providers.push(root.cloneProvider(p, {
                                            enabled: i === index
                                        }));
                                    } else {
                                        providers.push(root.cloneProvider(p, {
                                            enabled: i === index ? false : (p.enabled !== false)
                                        }));
                                    }
                                } else {
                                    providers.push(p);
                                }
                            }

                            Config.utilities.vpn.provider = providers;
                            Config.save();
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.normal
                        spacing: Appearance.spacing.normal

                        TextButton {
                            Layout.fillWidth: true
                            Layout.minimumHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                            visible: root.providerEnabled
                            enabled: !VPN.connecting && (!root.isFastestVpn || (root.fvpnHasAuth && root.fvpnHasConfigs))
                            inactiveColour: Colours.palette.m3primary
                            inactiveOnColour: Colours.palette.m3onPrimary
                            text: VPN.connected ? qsTr("Disconnect") : qsTr("Connect")

                            onClicked: {
                                if (VPN.connected) {
                                    VPN.disconnect();
                                    return;
                                }
                                if (root.isFastestVpn && !root.fvpnHasCaps && !VPN.fvpnSystemReady) {
                                    VPN.ensureSystemThenConnect(() => root.closeForPolkit());
                                    return;
                                }
                                VPN.connect();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Edit Provider")
                            inactiveColour: Colours.palette.m3secondaryContainer
                            inactiveOnColour: Colours.palette.m3onSecondaryContainer

                            onClicked: {
                                editVpnDialog.editIndex = root.vpnProvider.index;
                                editVpnDialog.providerName = root.vpnProvider.name;
                                editVpnDialog.displayName = root.vpnProvider.displayName;
                                editVpnDialog.interfaceName = root.vpnProvider.interface;
                                editVpnDialog.open();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Delete Provider")
                            inactiveColour: Colours.palette.m3errorContainer
                            inactiveOnColour: Colours.palette.m3onErrorContainer

                            onClicked: {
                                const providers = [];
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    if (i !== root.vpnProvider.index) {
                                        providers.push(Config.utilities.vpn.provider[i]);
                                    }
                                }
                                Config.utilities.vpn.provider = providers;
                                Config.save();
                                root.session.vpn.active = null;
                            }
                        }
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal
                visible: root.isFastestVpn

                SectionHeader {
                    title: qsTr("FastestVPN setup")
                    description: qsTr("Save credentials, then Connect. Scans keep running if you close settings.")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.normal

                    PropertyRow {
                        label: qsTr("Status")
                        value: root.fvpnReadyText
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: root.fvpnHasAuth ? qsTr("Update credentials") : qsTr("Save credentials")
                        inactiveColour: Colours.palette.m3primary
                        inactiveOnColour: Colours.palette.m3onPrimary
                        onClicked: credDialog.open()
                    }

                    PropertyRow {
                        label: qsTr("Default server")
                        value: root.fvpnDefault
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Latency and download caches are saved separately. You can close settings while a scan runs.")
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Scan latency")
                            enabled: !root.fvpnJobRunning
                            inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                            inactiveOnColour: Colours.palette.m3onSurface
                            onClicked: root.startRank("latency")
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Scan download/upload")
                            enabled: !root.fvpnJobRunning && root.fvpnHasAuth
                            inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                            inactiveOnColour: Colours.palette.m3onSurface
                            onClicked: root.startRank("speed")
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.fvpnHasAuth
                        text: qsTr("Save credentials first to enable download/upload ranking.")
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3error
                    }

                    TextButton {
                        Layout.fillWidth: true
                        visible: root.fvpnJobRunning
                        text: qsTr("Stop scan")
                        inactiveColour: Colours.palette.m3errorContainer
                        inactiveOnColour: Colours.palette.m3onErrorContainer
                        onClicked: fvpnRankStopProc.exec([VPN.fvpnPath, "rank-stop"])
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller / 2
                        visible: root.fvpnJobRunning || root.fvpnJobProgressText.length > 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            MaterialIcon {
                                id: rankSpinner
                                visible: root.fvpnJobRunning
                                text: "progress_activity"
                                font.pointSize: Appearance.font.size.large
                                color: Colours.palette.m3primary

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: root.fvpnJobRunning && rankSpinner.visible
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.fvpnJobProgressText
                                wrapMode: Text.Wrap
                                font.pointSize: Appearance.font.size.small
                                color: root.fvpnJobStatus === "error"
                                    ? Colours.palette.m3error
                                    : Colours.palette.m3onSurfaceVariant
                            }
                        }

                        StyledRect {
                            id: rankBarTrack
                            Layout.fillWidth: true
                            visible: root.fvpnJobRunning
                            implicitHeight: 8
                            radius: Appearance.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHighest
                            clip: true

                            // Determinate fill when we know X/Y
                            StyledRect {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: root.fvpnJobFraction > 0.02
                                width: Math.max(8, parent.width * root.fvpnJobFraction)
                                radius: parent.radius
                                color: Colours.palette.m3primary

                                Behavior on width {
                                    Anim {
                                        duration: Appearance.anim.durations.small
                                    }
                                }
                            }

                            // Indeterminate pulse while still "Starting…"
                            StyledRect {
                                id: rankBarPulse
                                visible: root.fvpnJobRunning && root.fvpnJobFraction <= 0.02
                                width: parent.width * 0.28
                                height: parent.height
                                radius: parent.radius
                                color: Colours.palette.m3primary

                                SequentialAnimation on x {
                                    running: rankBarPulse.visible
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: -rankBarTrack.width * 0.28
                                        to: rankBarTrack.width
                                        duration: 1100
                                        easing.type: Easing.InOutCubic
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("View latency")
                            inactiveColour: root.fvpnViewMode === "latency"
                                ? Colours.palette.m3primary
                                : Colours.tPalette.m3surfaceContainerHigh
                            inactiveOnColour: root.fvpnViewMode === "latency"
                                ? Colours.palette.m3onPrimary
                                : Colours.palette.m3onSurface
                            onClicked: root.fvpnViewMode = "latency"
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("View download")
                            inactiveColour: root.fvpnViewMode === "speed"
                                ? Colours.palette.m3primary
                                : Colours.tPalette.m3surfaceContainerHigh
                            inactiveOnColour: root.fvpnViewMode === "speed"
                                ? Colours.palette.m3onPrimary
                                : Colours.palette.m3onSurface
                            onClicked: root.fvpnViewMode = "speed"
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.fvpnViewMode === "speed"
                            ? root.cacheHint(root.fvpnSpeedMeta)
                            : root.cacheHint(root.fvpnLatencyMeta)
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: {
                            const age = root.fvpnViewMode === "speed" ? root.fvpnSpeedMeta?.ageSec : root.fvpnLatencyMeta?.ageSec;
                            return (age !== null && age !== undefined && age > 6 * 3600)
                                ? Colours.palette.m3tertiary
                                : Colours.palette.m3outline;
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.fvpnViewMode === "speed"
                        text: qsTr("Both scans cover every reachable UDP server. Download connects one-by-one (can take a long time — safe to close settings).")
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3outline
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller / 2
                        visible: root.fvpnRankResults.length > 0

                        StyledText {
                            text: qsTr("Servers (tap to set default)")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Repeater {
                            model: root.fvpnRankResults

                            TextButton {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                                Layout.minimumHeight: Layout.preferredHeight
                                inactiveColour: modelData.server === root.fvpnDefault
                                    ? Colours.palette.m3primary
                                    : Colours.tPalette.m3surfaceContainerHigh
                                inactiveOnColour: modelData.server === root.fvpnDefault
                                    ? Colours.palette.m3onPrimary
                                    : Colours.palette.m3onSurface
                                text: {
                                    const n = index + 1;
                                    const mark = modelData.server === root.fvpnDefault ? " ★" : "";
                                    if (root.fvpnViewMode === "speed") {
                                        const down = root.formatMbps(modelData.downloadMbps);
                                        const up = root.formatMbps(modelData.uploadMbps);
                                        const lat = root.formatLatency(modelData.latencyMs);
                                        return qsTr("%1. %2 — ↓%3 ↑%4 · %5%6").arg(n).arg(modelData.server).arg(down).arg(up).arg(lat).arg(mark);
                                    }
                                    return qsTr("%1. %2 — %3%4").arg(n).arg(modelData.server).arg(root.formatLatency(modelData.latencyMs)).arg(mark);
                                }
                                onClicked: root.setDefaultServer(modelData.server)
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.fvpnRankResults.length === 0
                        text: root.fvpnViewMode === "speed"
                            ? qsTr("No download cache yet — run “Scan download/upload”.")
                            : qsTr("No latency cache yet — run “Scan latency”.")
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3outline
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.fvpnServers.length > 0
                        text: qsTr("%1 UDP servers available").arg(root.fvpnServers.length)
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3outline
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SectionHeader {
                    title: qsTr("Provider details")
                    description: qsTr("VPN provider information")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.small / 2

                    PropertyRow {
                        label: qsTr("Provider")
                        value: root.vpnProvider?.name ?? qsTr("Unknown")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Display name")
                        value: root.vpnProvider?.displayName ?? qsTr("Unknown")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Interface")
                        value: root.vpnProvider?.interface || qsTr("N/A")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Status")
                        value: {
                            if (!root.providerEnabled)
                                return qsTr("Disabled");
                            if (VPN.connecting)
                                return qsTr("Connecting...");
                            if (VPN.connected)
                                return qsTr("Connected");
                            return qsTr("Enabled (Not connected)");
                        }
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Enabled")
                        value: root.providerEnabled ? qsTr("Yes") : qsTr("No")
                    }
                }
            }
        }
    ]

    Popup {
        id: credDialog

        property string username: ""
        property string password: ""

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - Appearance.padding.large * 2)
        padding: Appearance.padding.large * 1.5
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: StyledRect {
            color: Colours.palette.m3surfaceContainerHigh
            radius: Appearance.rounding.large
            Elevation {
                anchors.fill: parent
                radius: parent.radius
                level: 3
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: Appearance.spacing.normal

            StyledText {
                text: qsTr("FastestVPN credentials")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            StyledTextField {
                Layout.fillWidth: true
                implicitHeight: 40
                placeholderText: qsTr("Username")
                text: credDialog.username
                onTextChanged: credDialog.username = text
            }

            StyledTextField {
                Layout.fillWidth: true
                implicitHeight: 40
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                text: credDialog.password
                onTextChanged: credDialog.password = text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    onClicked: credDialog.close()
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Save")
                    enabled: credDialog.username.length > 0 && credDialog.password.length > 0
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary
                    onClicked: {
                        // User-owned auth file — no pkexec. Pass argv so special chars are safe.
                        fvpnSetupProc.exec([
                            "bash", "-c",
                            `printf '%s\\n%s\\n' "$1" "$2" | ${VPN.fvpnPath} setup-stdin`,
                            "fvpn-setup",
                            credDialog.username,
                            credDialog.password
                        ]);
                        credDialog.password = "";
                        credDialog.close();
                    }
                }
            }
        }
    }

    // Edit VPN Dialog
    Popup {
        id: editVpnDialog

        property int editIndex: -1
        property string providerName: ""
        property string displayName: ""
        property string interfaceName: ""

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - Appearance.padding.large * 2)
        padding: Appearance.padding.large * 1.5

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        opacity: 0
        scale: 0.7

        enter: Transition {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
            Anim {
                property: "scale"
                from: 0.7
                to: 1
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        exit: Transition {
            Anim {
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
            Anim {
                property: "scale"
                from: 1
                to: 0.7
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        function closeWithAnimation(): void {
            close();
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.4 * editVpnDialog.opacity)
        }

        background: StyledRect {
            color: Colours.palette.m3surfaceContainerHigh
            radius: Appearance.rounding.large

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                level: 3
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: Appearance.spacing.normal

            StyledText {
                text: qsTr("Edit VPN Provider")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller / 2

                StyledText {
                    text: qsTr("Display Name")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledTextField {
                    id: displayNameField

                    Layout.fillWidth: true
                    implicitHeight: 40
                    horizontalAlignment: TextInput.AlignLeft
                    text: editVpnDialog.displayName
                    onTextChanged: editVpnDialog.displayName = text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller / 2

                StyledText {
                    text: qsTr("Interface (e.g., wg0, torguard)")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledTextField {
                    id: interfaceNameField

                    Layout.fillWidth: true
                    implicitHeight: 40
                    horizontalAlignment: TextInput.AlignLeft
                    text: editVpnDialog.interfaceName
                    onTextChanged: editVpnDialog.interfaceName = text
                }
            }

            RowLayout {
                Layout.topMargin: Appearance.spacing.normal
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurface
                    onClicked: editVpnDialog.closeWithAnimation()
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Save")
                    enabled: editVpnDialog.interfaceName.length > 0
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary

                    onClicked: {
                        const providers = [];
                        const oldProvider = Config.utilities.vpn.provider[editVpnDialog.editIndex];
                        const wasEnabled = typeof oldProvider === "object" ? (oldProvider.enabled !== false) : true;

                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            if (i === editVpnDialog.editIndex) {
                                providers.push(root.cloneProvider(oldProvider, {
                                    name: editVpnDialog.providerName,
                                    displayName: editVpnDialog.displayName || editVpnDialog.interfaceName,
                                    interface: editVpnDialog.interfaceName,
                                    enabled: wasEnabled
                                }));
                            } else {
                                providers.push(Config.utilities.vpn.provider[i]);
                            }
                        }

                        Config.utilities.vpn.provider = providers;
                        Config.save();
                        editVpnDialog.closeWithAnimation();
                    }
                }
            }
        }
    }
}
