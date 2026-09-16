pragma Singleton
pragma ComponentBehavior: Bound

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/files/fm.py")
    readonly property string home: {
        const h = Paths.home || Quickshell.env("HOME") || "";
        return h.length ? h : "/";
    }

    property string dirDownloads: `${home}/Downloads`
    property string dirDocuments: `${home}/Documents`
    property string dirPictures: `${home}/Pictures`
    property string dirVideos: `${home}/Videos`
    property string dirMusic: `${home}/Music`
    property string dirDesktop: `${home}/Desktop`
    property var places: [
        {
            key: "home",
            label: "Home",
            path: home,
            icon: "home"
        },
        {
            key: "trash",
            label: "Trash",
            path: "trash://",
            icon: "delete"
        }
    ]
    property var pinnedPlaces: []

    property var mounts: []
    property string mountsSignature: ""

    property string clipboardMode: ""
    property var clipboardPaths: []

    property bool jobActive: false
    property bool jobSettled: false
    property real jobProgress: 0
    property string jobLabel: ""
    property string jobKind: ""
    property var jobOwner: null

    function formatBytes(bytes: real): string {
        const kib = bytes / 1024;
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;
        if (kib >= tib)
            return `${(kib / tib).toFixed(1)} TiB`;
        if (kib >= gib)
            return `${(kib / gib).toFixed(1)} GiB`;
        if (kib >= mib)
            return `${(kib / mib).toFixed(1)} MiB`;
        if (bytes >= 1024)
            return `${(bytes / 1024).toFixed(0)} KiB`;
        return `${Math.round(bytes)} B`;
    }

    function normalizeFsPath(path: string): string {
        let p = String(path || "");
        if (p.startsWith("file://"))
            p = p.slice("file://".length);
        if (p.startsWith("//")) {
            const slash = p.indexOf("/", 2);
            p = slash >= 0 ? p.slice(slash) : p;
        }
        try {
            p = decodeURIComponent(p);
        } catch (e) {}
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.endsWith("/"))
            p = p.replace(/\/+$/, "");
        return p;
    }

    function isBuiltinPlace(path: string): bool {
        const p = normalizeFsPath(path);
        if (!p.length)
            return true;
        const list = root.places;
        for (let i = 0; i < list.length; ++i) {
            if (normalizeFsPath(list[i].path) === p)
                return true;
        }
        return false;
    }

    function isPinned(path: string): bool {
        const p = normalizeFsPath(path);
        if (!p.length)
            return false;
        const list = root.pinnedPlaces;
        for (let i = 0; i < list.length; ++i) {
            if (normalizeFsPath(list[i].path) === p)
                return true;
        }
        return false;
    }

    function pinFolders(paths: var): void {
        if (!paths || !paths.length)
            return;
        const next = root.pinnedPlaces.slice();
        let changed = false;
        for (let i = 0; i < paths.length; ++i) {
            const p = normalizeFsPath(paths[i]);
            if (!p.length || p === "trash://" || p.startsWith("trash://"))
                continue;
            if (root.isBuiltinPlace(p) || next.some(x => normalizeFsPath(x.path) === p))
                continue;
            const parts = p.split("/").filter(s => s.length);
            const label = parts.length ? parts[parts.length - 1] : p;
            next.push({
                key: "pin:" + p,
                label: label,
                path: p,
                icon: "folder"
            });
            changed = true;
        }
        if (!changed)
            return;
        root.pinnedPlaces = next;
        root.savePinned();
    }

    function unpinFolder(path: string): void {
        const p = normalizeFsPath(path);
        const next = root.pinnedPlaces.filter(x => normalizeFsPath(x.path) !== p);
        if (next.length === root.pinnedPlaces.length)
            return;
        root.pinnedPlaces = next;
        root.savePinned();
    }

    function savePinned(): void {
        pinnedFile.setText(JSON.stringify(root.pinnedPlaces));
    }

    function refreshMounts(): void {
        mountsProc.running = false;
        mountsProc.running = true;
    }

    function startJob(kind: string, label: string, command: list<string>, owner: var): void {
        if (jobActive)
            return;
        jobActive = true;
        jobSettled = false;
        jobKind = kind;
        jobLabel = label;
        jobProgress = 0;
        jobOwner = owner || null;
        opProc.command = command;
        opProc.kind = kind;
        opProc.renameAfter = "";
        opProc.running = true;
    }

    function finishJob(): void {
        jobSettled = true;
        jobActive = false;
        jobProgress = 0;
        jobLabel = "";
        jobKind = "";
        jobOwner = null;
    }

    function smartExtract(archivePath: string, destPath: string, owner: var): void {
        if (!archivePath || !archivePath.length || jobActive)
            return;
        const name = archivePath.split("/").pop() || qsTr("archive");
        const dest = destPath || home;
        startJob("extract", qsTr("Extracting %1").arg(name), ["python3", "-u", script, "smart-extract", archivePath, "--dest", dest], owner);
    }

    function pasteClipboard(destPath: string, owner: var): void {
        if (!clipboardPaths.length || !clipboardMode.length || jobActive)
            return;
        const kind = clipboardMode === "cut" ? "move" : "copy";
        const dest = destPath || home;
        startJob(kind, kind === "cut" ? qsTr("Moving…") : qsTr("Copying…"), ["python3", "-u", script, kind, dest].concat(clipboardPaths), owner);
        if (clipboardMode === "cut") {
            clipboardPaths = [];
            clipboardMode = "";
        }
    }

    function trashSelection(paths: var, owner: var): void {
        if (!paths || !paths.length || jobActive)
            return;
        startJob("trash", qsTr("Moving to Trash…"), ["python3", "-u", script, "trash"].concat(paths), owner);
    }

    function deletePermanent(paths: var, owner: var): void {
        if (!paths || !paths.length || jobActive)
            return;
        startJob("delete", qsTr("Deleting permanently…"), ["python3", "-u", script, "delete"].concat(paths), owner);
    }

    function restoreTrash(uris: var, owner: var): void {
        if (!uris || !uris.length || jobActive)
            return;
        startJob("restore", qsTr("Restoring…"), ["python3", "-u", script, "restore"].concat(uris), owner);
    }

    function emptyTrash(owner: var): void {
        if (jobActive)
            return;
        startJob("empty-trash", qsTr("Emptying Trash…"), ["python3", "-u", script, "empty-trash"], owner);
    }

    function notifyOwner(owner: var, title: string, message: string, icon: string): void {
        if (owner && owner.showAppToast) {
            owner.showAppToast(title, message, icon);
            return;
        }
        Toaster.toast(title, message, icon, 1);
    }

    function notifyOwnerError(owner: var, message: string): void {
        if (owner && owner.showAppToast) {
            owner.showAppToast(qsTr("Files"), message || qsTr("Operation failed"), "error");
            return;
        }
        Toaster.toast(qsTr("Files"), message || qsTr("Operation failed"), "error", 3);
    }

    function ejectVolume(mountPath: string, owner: var): void {
        if (!mountPath || !mountPath.length || jobActive)
            return;
        startJob("eject", qsTr("Ejecting…"), ["python3", "-u", script, "eject", mountPath], owner);
    }

    function mountVolume(devicePath: string, owner: var): void {
        if (!devicePath || !devicePath.length || jobActive)
            return;
        startJob("mount", qsTr("Mounting…"), ["python3", "-u", script, "mount", devicePath], owner);
    }

    function openFile(path: string, owner: var): void {
        if (!path || !path.length)
            return;
        openProc.owner = owner || null;
        openProc.command = ["python3", "-u", script, "open", path];
        openProc.running = true;
    }

    function importPaths(paths: var, destPath: string, owner: var): void {
        transferPaths(paths, destPath, false, owner);
    }

    function transferPaths(paths: var, destPath: string, move: bool, owner: var): void {
        if (!paths || !paths.length || jobActive)
            return;
        const dest = destPath || home;
        const kind = move ? "move" : "copy";
        startJob(kind, move ? qsTr("Moving…") : qsTr("Copying…"), ["python3", "-u", script, kind, dest].concat(paths), owner);
    }

    function undoMove(items: var, owner: var): void {
        if (!items || !items.length || jobActive)
            return;
        const args = ["python3", "-u", script, "undo-move"];
        for (let i = 0; i < items.length; ++i) {
            const it = items[i];
            if (!it || !it.to || !it.from)
                continue;
            args.push(String(it.to));
            args.push(String(it.from));
        }
        if (args.length <= 4)
            return;
        startJob("undo-move", qsTr("Undoing…"), args, owner);
    }

    function runQuick(command: list<string>, kind: string, renameAfter: string, owner: var): void {
        if (jobActive)
            return;
        startJob(kind, kind === "mkdir" ? qsTr("Creating folder…") : qsTr("Working…"), command, owner);
        opProc.renameAfter = renameAfter || "";
    }

    function fetchInfo(paths: var, owner: var): void {
        if (!paths || !paths.length)
            return;
        infoProc.running = false;
        infoProc.owner = owner || null;
        infoProc.command = ["python3", "-u", script, "info"].concat(paths);
        infoProc.running = true;
    }

    Process {
        id: infoProc
        property var owner: null
        stdout: StdioCollector {
            onStreamFinished: {
                const owner = infoProc.owner;
                try {
                    const data = JSON.parse(text);
                    if (owner && owner.onInfoReady)
                        owner.onInfoReady(data);
                } catch (e) {
                    if (owner && owner.onInfoReady)
                        owner.onInfoReady({
                            ok: false,
                            error: qsTr("Failed to read properties")
                        });
                }
                infoProc.owner = null;
            }
        }
    }

    Process {
        id: openProc
        property var owner: null
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const owner = openProc.owner;
                    if (data.ok === false || data.type === "error")
                        root.notifyOwnerError(owner, data.error || qsTr("Failed to open file"));
                } catch (e) {}
                openProc.owner = null;
            }
        }
    }

    Process {
        id: xdgDirsProc
        command: ["python3", "-u", root.script, "xdg-dirs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.ok)
                        return;
                    if (data.downloads)
                        root.dirDownloads = data.downloads;
                    if (data.documents)
                        root.dirDocuments = data.documents;
                    if (data.pictures)
                        root.dirPictures = data.pictures;
                    if (data.videos)
                        root.dirVideos = data.videos;
                    if (data.music)
                        root.dirMusic = data.music;
                    if (data.desktop)
                        root.dirDesktop = data.desktop;
                    if (data.places && data.places.length) {
                        const list = data.places.slice();
                        if (!list.some(p => p.key === "trash" || p.path === "trash://"))
                            list.push({
                                key: "trash",
                                label: "Trash",
                                path: "trash://",
                                icon: "delete"
                            });
                        root.places = list;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: mountsProc
        command: ["python3", "-u", root.script, "mounts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.ok)
                        return;
                    const next = data.mounts || [];
                    const sig = next.map(m => `${m.devicePath || ""}|${m.mount || ""}|${m.mounted ? 1 : 0}|${Math.round((m.perc || 0) * 100)}|${Math.round((m.free || 0) / (16 * 1024 * 1024))}`).join(";");
                    if (sig === root.mountsSignature)
                        return;
                    root.mountsSignature = sig;
                    root.mounts = next;
                } catch (e) {}
            }
        }
    }

    Process {
        id: opProc
        property string kind: ""
        property string renameAfter: ""

        stdout: SplitParser {
            onRead: line => {
                const raw = String(line || "").trim();
                if (!raw.length)
                    return;
                try {
                    const data = JSON.parse(raw);
                    if (data.type === "progress") {
                        root.jobActive = true;
                        root.jobProgress = data.progress ?? root.jobProgress;
                        if (data.message)
                            root.jobLabel = data.message;
                        return;
                    }

                    const owner = root.jobOwner;
                    const kind = opProc.kind;

                    if (data.ok === false || data.type === "error") {
                        root.notifyOwnerError(owner, data.error || qsTr("Operation failed"));
                        root.finishJob();
                        if (owner && owner.refresh)
                            owner.refresh();
                        return;
                    }

                    if (kind === "extract")
                        root.notifyOwner(owner, qsTr("Extracted"), data.result || "", "folder_zip");
                    else if (kind === "copy")
                        root.notifyOwner(owner, qsTr("Pasted"), qsTr("Done"), "check_circle");
                    else if (kind === "move") {
                        // Undo toast handled by session.onJobDone
                    } else if (kind === "undo-move")
                        root.notifyOwner(owner, qsTr("Undone"), qsTr("Move undone"), "undo");
                    else if (kind === "delete")
                        root.notifyOwner(owner, qsTr("Deleted"), qsTr("%1 item(s) permanently deleted").arg(data.count || 0), "delete_forever");
                    else if (kind === "restore")
                        root.notifyOwner(owner, qsTr("Restored"), qsTr("%1 item(s)").arg(data.count || 0), "undo");
                    else if (kind === "empty-trash")
                        root.notifyOwner(owner, qsTr("Trash emptied"), "", "delete_sweep");
                    else if (kind === "eject") {
                        // Quiet: udiskie/system may already show one “Device unmounted”.
                    } else if (kind === "mount") {
                        // Navigation handled by session.onJobDone
                    }
                    // trash: in-window undo toast handled by session

                    const payload = data || {};
                    if (opProc.renameAfter.length)
                        payload.renameAfter = opProc.renameAfter;
                    opProc.renameAfter = "";

                    root.finishJob();
                    if (owner && owner.onJobDone)
                        owner.onJobDone(kind, payload);
                    else if (owner && owner.refresh)
                        owner.refresh();
                    root.refreshMounts();
                } catch (e) {}
            }
        }

        onRunningChanged: {
            if (running)
                return;
            if (root.jobActive && !root.jobSettled) {
                const owner = root.jobOwner;
                root.notifyOwnerError(owner, qsTr("Operation interrupted"));
                root.finishJob();
                if (owner && owner.refresh)
                    owner.refresh();
            }
        }
    }

    FileView {
        id: pinnedFile
        path: `${Paths.state}/fm-pinned.json`
        onLoaded: {
            try {
                const data = JSON.parse(text() || "[]");
                const list = Array.isArray(data) ? data.filter(p => p && p.path) : [];
                root.pinnedPlaces = list.map(p => {
                    const item = Object.assign({}, p);
                    if (!item.icon || item.icon === "bookmark")
                        item.icon = "folder";
                    return item;
                });
            } catch (e) {
                root.pinnedPlaces = [];
            }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                setText("[]");
            root.pinnedPlaces = [];
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMounts()
    }
}
