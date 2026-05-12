pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    /// Clients that look off-monitor (see `windowNeedsRecoveryReason`) — updated with hyprctl clients/monitors.
    property var recoveryCandidates: []

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        getClients.running = true;
    }

    function updateLayers() {
        getLayers.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return !(ax + aw <= bx || ax >= bx + bw || ay + ah <= by || ay >= by + bh);
    }

    function windowOverlapsAnyMonitor(win) {
        const mons = root.monitors;
        if (!mons || mons.length === 0)
            return true;
        const x = win.at[0], y = win.at[1], w = win.size[0], h = win.size[1];
        for (let i = 0; i < mons.length; ++i) {
            const m = mons[i];
            if (root.rectsOverlap(x, y, w, h, m.x, m.y, m.width, m.height))
                return true;
        }
        return false;
    }

    function windowCenterInsideAnyMonitor(win) {
        const mons = root.monitors;
        if (!mons || mons.length === 0)
            return true;
        const cx = win.at[0] + win.size[0] * 0.5;
        const cy = win.at[1] + win.size[1] * 0.5;
        for (let i = 0; i < mons.length; ++i) {
            const m = mons[i];
            if (cx >= m.x && cx < m.x + m.width && cy >= m.y && cy < m.y + m.height)
                return true;
        }
        return false;
    }

    /// Returns null if OK, else a short reason code for UI.
    function windowNeedsRecoveryReason(win) {
        if (!win.mapped || win.hidden)
            return null;
        if (!win.at || !win.size || win.size[0] < 1 || win.size[1] < 1)
            return null;
        if (win.fullscreen)
            return null;
        if ((win.fullscreenClient | 0) > 0)
            return null;
        const overlap = root.windowOverlapsAnyMonitor(win);
        const centerIn = root.windowCenterInsideAnyMonitor(win);
        if (!overlap)
            return win.floating ? "no_overlap" : "no_overlap_tiled";
        if (!win.floating)
            return null;
        if (!centerIn)
            return "center_off";
        return null;
    }

    function recomputeRecoveryCandidates(): void {
        const out = [];
        const wins = root.windowList;
        if (!wins) {
            root.recoveryCandidates = out;
            return;
        }
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i];
            const reason = root.windowNeedsRecoveryReason(w);
            if (!reason)
                continue;
            out.push({
                address: w.address,
                class: w.class || "",
                title: w.title || "",
                reason: reason,
                floating: !!w.floating
            });
        }
        root.recoveryCandidates = out;
    }

    function _focusedMonitorBox() {
        const mons = root.monitors;
        if (!mons || mons.length === 0)
            return null;
        const fmId = Hyprland.focusedMonitor?.id ?? mons[0].id;
        for (let i = 0; i < mons.length; ++i) {
            if (mons[i].id == fmId)
                return mons[i];
        }
        return mons[0];
    }

    function _moveWindowToFocusedCenter(win, staggerIndex) {
        const box = root._focusedMonitorBox();
        if (!box)
            return;
        const mx = box.x, my = box.y, mw = box.width, mh = box.height;
        const ww = win.size[0], wh = win.size[1];
        const k = staggerIndex || 0;
        let nx = mx + Math.max(0, Math.floor((mw - ww) / 2)) + k * 48;
        nx = Math.min(nx, mx + mw - ww - 5);
        const ny = my + Math.max(0, Math.floor((mh - wh) / 2));
        Hyprland.dispatch(`movewindowpixel exact ${nx} ${ny},address:${win.address}`);
    }

    function collectRecoveryFloatingWindows() {
        const wins = root.windowList;
        const off = [];
        if (!wins)
            return off;
        for (let j = 0; j < wins.length; ++j) {
            const w = wins[j];
            if (!w.floating)
                continue;
            if (root.windowNeedsRecoveryReason(w))
                off.push(w);
        }
        off.sort((a, b) => (b.size[0] * b.size[1]) - (a.size[0] * a.size[1]));
        return off;
    }

    property string _pendingBringOneAddress: ""

    Timer {
        id: bringOneTimer
        interval: 220
        repeat: false
        onTriggered: {
            const addr = root._pendingBringOneAddress;
            root._pendingBringOneAddress = "";
            if (!addr)
                return;
            const wins = root.windowList;
            if (!wins)
                return;
            let w = null;
            for (let i = 0; i < wins.length; ++i) {
                if (wins[i].address === addr) {
                    w = wins[i];
                    break;
                }
            }
            if (!w || !w.floating)
                return;
            root._moveWindowToFocusedCenter(w, 0);
            root.updateWindowList();
        }
    }

    function bringOneWindowInRequest(addr: string): void {
        root._pendingBringOneAddress = addr;
        root.updateWindowList();
        root.updateMonitors();
        bringOneTimer.restart();
    }

    function refreshRecoveryUi(): void {
        root.updateWindowList();
        root.updateMonitors();
    }

    function bringOffscreenFloatsInRequest(): void {
        root.updateWindowList();
        root.updateMonitors();
        bringOffscreenTimer.restart();
    }

    function _bringOffscreenFloatsInWork(): void {
        const off = root.collectRecoveryFloatingWindows();
        if (off.length === 0)
            return;

        for (let k = 0; k < off.length; ++k)
            root._moveWindowToFocusedCenter(off[k], k);
        root.updateWindowList();
    }

    Timer {
        id: bringOffscreenTimer
        interval: 220
        repeat: false
        onTriggered: root._bringOffscreenFloatsInWork()
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // console.log("Hyprland raw event:", event.name);
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            updateAll()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
                root.recomputeRecoveryCandidates();
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
                root.recomputeRecoveryCandidates();
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
