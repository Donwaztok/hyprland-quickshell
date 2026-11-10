pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Hyprland state not exposed by Quickshell.Hyprland (hyprctl clients, monitors, recovery, etc.).
 */
Singleton {
    id: root

    property var windowList: []
    property var windowByAddress: ({})
    property var monitors: []
    property var layers: ({})

    /// Off-monitor clients for the recovery UI (see windowNeedsRecoveryReason).
    property var recoveryCandidates: []

    // --- Public queries -------------------------------------------------------

    function biggestWindowForWorkspace(workspaceId) {
        return root.windowList
            .filter(w => w.workspace.id == workspaceId)
            .reduce((best, win) => {
                const area = (win.size?.[0] ?? 0) * (win.size?.[1] ?? 0);
                const bestArea = (best?.size?.[0] ?? 0) * (best?.size?.[1] ?? 0);
                return area > bestArea ? win : best;
            }, null);
    }

    // --- Hyprctl refresh ------------------------------------------------------

    // Setting running while a run is in flight is a no-op, so remember it and rerun in onExited.
    function _run(proc) {
        if (proc.running)
            proc.pending = true;
        else
            proc.running = true;
    }
    function updateWindowList() { _run(getClients); }
    function updateLayers() { _run(getLayers); }
    function updateMonitors() { _run(getMonitors); }
    function _rerunIfPending(proc) {
        if (!proc.pending)
            return;
        proc.pending = false;
        Qt.callLater(() => root._run(proc));
    }
    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
    }

    function refreshRecoveryUi() {
        updateWindowList();
        updateMonitors();
    }

    // --- Recovery detection ---------------------------------------------------

    function _windowMonitorState(win) {
        const mons = root.monitors;
        if (!mons?.length)
            return { overlap: true, centerIn: true };

        const [x, y] = win.at;
        const [w, h] = win.size;
        const cx = x + w * 0.5;
        const cy = y + h * 0.5;
        let overlap = false;
        let centerIn = false;

        for (let i = 0; i < mons.length; ++i) {
            const m = mons[i];
            if (!overlap && !(x + w <= m.x || x >= m.x + m.width || y + h <= m.y || y >= m.y + m.height))
                overlap = true;
            if (!centerIn && cx >= m.x && cx < m.x + m.width && cy >= m.y && cy < m.y + m.height)
                centerIn = true;
            if (overlap && centerIn)
                break;
        }
        return { overlap, centerIn };
    }

    /// null when OK, else a short reason code for the UI.
    function windowNeedsRecoveryReason(win) {
        if (!win?.mapped || win.hidden || win.fullscreen || (win.fullscreenClient | 0) > 0)
            return null;
        if (!win.at || !win.size || win.size[0] < 1 || win.size[1] < 1)
            return null;

        const { overlap, centerIn } = root._windowMonitorState(win);
        if (!overlap)
            return win.floating ? "no_overlap" : "no_overlap_tiled";
        if (win.floating && !centerIn)
            return "center_off";
        return null;
    }

    function recomputeRecoveryCandidates() {
        const wins = root.windowList ?? [];
        const out = [];
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i];
            const reason = root.windowNeedsRecoveryReason(w);
            if (!reason)
                continue;
            out.push({
                address: w.address,
                class: w.class || "",
                title: w.title || "",
                reason,
                floating: !!w.floating
            });
        }
        root.recoveryCandidates = out;
    }

    function _floatingWindowsNeedingRecovery() {
        return (root.windowList ?? [])
            .filter(w => w.floating && root.windowNeedsRecoveryReason(w))
            .sort((a, b) => (b.size[0] * b.size[1]) - (a.size[0] * a.size[1]));
    }

    // --- Recovery actions (Hyprland 0.55+ hl.dsp) -----------------------------

    function _dispatchRecoverWindow(address, staggerIndex) {
        if (!address)
            return;
        const sel = `address:${address}`;
        const wsId = Hyprland.focusedWorkspace?.id;
        const monName = Hyprland.focusedMonitor?.name;
        if (wsId != null)
            Hyprland.dispatch(`hl.dsp.window.move({ window = '${sel}', workspace = ${wsId}, follow = false })`);
        if (monName)
            Hyprland.dispatch(`hl.dsp.window.move({ window = '${sel}', monitor = '${monName}', follow = false })`);
        Hyprland.dispatch(`hl.dsp.window.center({ window = '${sel}' })`);
        const k = staggerIndex || 0;
        if (k > 0)
            Hyprland.dispatch(`hl.dsp.window.move({ window = '${sel}', x = ${k * 48}, y = 0, relative = true })`);
    }

    /// null | "all" | window address
    property var _recoveryAction: null
    property int _recoveryRefreshMask: 0

    readonly property int _recoveryClientsBit: 1
    readonly property int _recoveryMonitorsBit: 2

    function _requestRecovery(action) {
        root._recoveryAction = action;
        root._recoveryRefreshMask = 0;
        updateWindowList();
        updateMonitors();
    }

    function _recoveryRefreshDone(bit) {
        root._recoveryRefreshMask |= bit;
        if (root._recoveryRefreshMask !== (root._recoveryClientsBit | root._recoveryMonitorsBit))
            return;

        const action = root._recoveryAction;
        root._recoveryAction = null;
        root._recoveryRefreshMask = 0;
        if (!action)
            return;

        if (action === "all") {
            const wins = root._floatingWindowsNeedingRecovery();
            if (!wins.length)
                return;
            root._recoveryBatch = wins.map(w => w.address);
            root._recoveryIndex = 0;
            recoveryTimer.restart();
            return;
        }

        const win = root.windowByAddress[action];
        if (win?.floating)
            root._dispatchRecoverWindow(action, 0);
        updateWindowList();
    }

    function bringOneWindowInRequest(addr) {
        _requestRecovery(addr);
    }

    function bringOffscreenFloatsInRequest() {
        _requestRecovery("all");
    }

    property var _recoveryBatch: []
    property int _recoveryIndex: 0

    Timer {
        id: recoveryTimer
        interval: 120
        repeat: false
        onTriggered: {
            const batch = root._recoveryBatch;
            if (root._recoveryIndex >= batch.length) {
                root._recoveryBatch = [];
                root._recoveryIndex = 0;
                root.updateWindowList();
                return;
            }
            root._dispatchRecoverWindow(batch[root._recoveryIndex], root._recoveryIndex);
            root._recoveryIndex++;
            if (root._recoveryIndex < batch.length)
                recoveryTimer.restart();
            else {
                root._recoveryBatch = [];
                root._recoveryIndex = 0;
                root.updateWindowList();
            }
        }
    }

    // --- Lifecycle ------------------------------------------------------------

    Component.onCompleted: updateAll()

    property bool _wantClients: false
    property bool _wantMonitors: false
    property bool _wantLayers: false

    Timer {
        id: eventRefreshDebounce
        interval: 50
        repeat: false
        onTriggered: {
            if (root._wantClients)
                root.updateWindowList();
            if (root._wantMonitors)
                root.updateMonitors();
            if (root._wantLayers)
                root.updateLayers();
            root._wantClients = root._wantMonitors = root._wantLayers = false;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "screencast")
                return;
            if (n === "openlayer" || n === "closelayer") {
                root._wantLayers = true;
            } else {
                root._wantClients = true;
                // Consumers read only monitor geometry and layer rects; both change only with monitors.
                if (n.startsWith("monitor") || n === "configreloaded")
                    root._wantMonitors = root._wantLayers = true;
            }
            eventRefreshDebounce.restart();
        }
    }

    // --- Hyprctl processes ----------------------------------------------------

    Process {
        id: getClients
        property bool pending: false
        command: ["hyprctl", "clients", "-j"]
        onExited: root._rerunIfPending(getClients)
        stdout: StdioCollector {
            onStreamFinished: {
                let wins;
                try {
                    wins = JSON.parse(this.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse clients:", e);
                    return;
                }
                const byAddress = {};
                for (let i = 0; i < wins.length; ++i)
                    byAddress[wins[i].address] = wins[i];
                root.windowList = wins;
                root.windowByAddress = byAddress;
                root.recomputeRecoveryCandidates();
                root._recoveryRefreshDone(root._recoveryClientsBit);
            }
        }
    }

    Process {
        id: getMonitors
        property bool pending: false
        command: ["hyprctl", "monitors", "-j"]
        onExited: root._rerunIfPending(getMonitors)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(this.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse monitors:", e);
                    return;
                }
                root.recomputeRecoveryCandidates();
                root._recoveryRefreshDone(root._recoveryMonitorsBit);
            }
        }
    }

    Process {
        id: getLayers
        property bool pending: false
        command: ["hyprctl", "layers", "-j"]
        onExited: root._rerunIfPending(getLayers)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(this.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse layers:", e);
                }
            }
        }
    }
}
