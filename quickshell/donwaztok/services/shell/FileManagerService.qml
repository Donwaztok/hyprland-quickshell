pragma Singleton
pragma ComponentBehavior: Bound

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string binary: Quickshell.shellPath("bin/fm")
    readonly property string script: Quickshell.shellPath("scripts/files/fm.py") // legacy; prefer binary
    readonly property string home: {
        const h = Paths.home || Quickshell.env("HOME") || "";
        return h.length ? h : "/";
    }

    /** Build argv for the Rust fm helper: fm <subcommand> … */
    function fm(args: list<string>): list<string> {
        const out = [root.binary];
        for (let i = 0; i < args.length; ++i)
            out.push(args[i]);
        return out;
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

    // Job queue (one process at a time; UI can show several stacked)
    property var jobQueue: []
    property int jobSeq: 0
    property string currentJobId: ""

    property bool jobActive: false
    property bool jobSettled: false
    property real jobProgress: 0
    property string jobLabel: ""
    property string jobKind: ""
    property var jobOwner: null

    function iconForKind(kind: string): string {
        if (kind === "extract")
            return "folder_zip";
        if (kind === "compress")
            return "archive";
        if (kind === "move")
            return "drive_file_move";
        if (kind === "copy")
            return "content_copy";
        if (kind === "trash" || kind === "delete" || kind === "empty-trash")
            return "delete";
        if (kind === "restore" || kind === "undo-move")
            return "undo";
        if (kind === "mkdir")
            return "create_new_folder";
        return "progress_activity";
    }

    function startJob(kind: string, label: string, command: list<string>, owner: var, renameAfter: string): void {
        root.jobSeq += 1;
        const id = "job-" + root.jobSeq;
        const item = {
            id: id,
            kind: kind,
            label: label || qsTr("Working…"),
            progress: 0,
            status: "pending",
            command: command,
            owner: owner || null,
            renameAfter: renameAfter || ""
        };
        root.jobQueue = root.jobQueue.concat([item]);
        root.jobActive = true;
        root.jobSettled = false;
        if (!root.currentJobId)
            root.pumpQueue();
        else
            root.syncLegacyJobProps();
    }

    function syncLegacyJobProps(): void {
        const running = root.jobQueue.find(j => j.status === "running");
        const pending = root.jobQueue.find(j => j.status === "pending");
        const cur = running || pending || null;
        if (!cur) {
            root.jobActive = false;
            root.jobKind = "";
            root.jobLabel = "";
            root.jobProgress = 0;
            root.jobOwner = null;
            return;
        }
        root.jobActive = true;
        root.jobKind = cur.kind;
        root.jobLabel = cur.label;
        root.jobProgress = cur.progress || 0;
        root.jobOwner = cur.owner;
    }

    function patchJob(id: string, fields: var): void {
        if (!id)
            return;
        root.jobQueue = root.jobQueue.map(j => {
            if (j.id !== id)
                return j;
            return Object.assign({}, j, fields);
        });
        if (id === root.currentJobId)
            root.syncLegacyJobProps();
    }

    function pumpQueue(): void {
        if (opProc.running)
            return;
        const next = root.jobQueue.find(j => j.status === "pending");
        if (!next) {
            root.currentJobId = "";
            root.syncLegacyJobProps();
            return;
        }
        root.jobQueue = root.jobQueue.map(j => j.id === next.id ? Object.assign({}, j, {
            status: "running"
        }) : j);
        root.currentJobId = next.id;
        root.jobSettled = false;
        root.syncLegacyJobProps();
        opProc.command = next.command;
        opProc.kind = next.kind;
        opProc.jobId = next.id;
        opProc.renameAfter = next.renameAfter || "";
        opProc.running = true;
    }

    function finishJob(): void {
        const id = root.currentJobId || opProc.jobId;
        root.jobSettled = true;
        if (id)
            root.jobQueue = root.jobQueue.filter(j => j.id !== id);
        root.currentJobId = "";
        opProc.jobId = "";
        opProc.kind = "";
        opProc.renameAfter = "";
        root.syncLegacyJobProps();
    }

    property bool jobCancelRequested: false

    /** Cancel a queued or running job by id. */
    function cancelJob(id: string): void {
        if (!id || id === "demo")
            return;
        const job = root.jobQueue.find(j => j.id === id);
        if (!job)
            return;

        if (job.status === "pending") {
            root.jobQueue = root.jobQueue.filter(j => j.id !== id);
            root.syncLegacyJobProps();
            return;
        }

        if (job.status === "running" && (root.currentJobId === id || opProc.jobId === id)) {
            root.jobCancelRequested = true;
            root.jobSettled = true;
            if (opProc.running)
                opProc.running = false;
            else {
                root.finishJob();
                root.jobCancelRequested = false;
                Qt.callLater(() => root.pumpQueue());
            }
            return;
        }

        root.jobQueue = root.jobQueue.filter(j => j.id !== id);
        root.syncLegacyJobProps();
    }

    function cancelAllJobs(): void {
        const ids = root.jobQueue.map(j => j.id);
        for (let i = 0; i < ids.length; ++i)
            root.cancelJob(ids[i]);
    }

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

    function smartExtract(archivePath: string, destPath: string, owner: var): void {
        if (!archivePath || !archivePath.length)
            return;
        const name = archivePath.split("/").pop() || qsTr("archive");
        const dest = destPath || home;
        startJob("extract", qsTr("Extracting %1").arg(name), fm(["smart-extract", archivePath, "--dest", dest]), owner, "");
    }

    function smartCompress(paths: var, destPath: string, format: string, owner: var): void {
        if (!paths || !paths.length)
            return;
        const dest = destPath || home;
        const fmt = (format && format.length) ? format : "zip";
        const label = fmt === "7z" ? qsTr("Compressing (7z)…") : qsTr("Compressing (zip)…");
        startJob("compress", label, fm(["smart-compress", dest, "--format", fmt].concat(paths)), owner, "");
    }

    function pasteClipboard(destPath: string, owner: var): void {
        if (!clipboardPaths.length || !clipboardMode.length)
            return;
        const kind = clipboardMode === "cut" ? "move" : "copy";
        const dest = destPath || home;
        startJob(kind, kind === "cut" ? qsTr("Moving…") : qsTr("Copying…"), fm([kind, dest].concat(clipboardPaths)), owner, "");
        if (clipboardMode === "cut") {
            clipboardPaths = [];
            clipboardMode = "";
        }
    }

    function trashSelection(paths: var, owner: var): void {
        if (!paths || !paths.length)
            return;
        startJob("trash", qsTr("Moving to Trash…"), fm(["trash"].concat(paths)), owner, "");
    }

    function deletePermanent(paths: var, owner: var): void {
        if (!paths || !paths.length)
            return;
        startJob("delete", qsTr("Deleting permanently…"), fm(["delete"].concat(paths)), owner, "");
    }

    function restoreTrash(uris: var, owner: var): void {
        if (!uris || !uris.length)
            return;
        startJob("restore", qsTr("Restoring…"), fm(["restore"].concat(uris)), owner, "");
    }

    function emptyTrash(owner: var): void {
        startJob("empty-trash", qsTr("Emptying Trash…"), fm(["empty-trash"]), owner, "");
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
        if (!mountPath || !mountPath.length)
            return;
        startJob("eject", qsTr("Ejecting…"), fm(["eject", mountPath]), owner, "");
    }

    function mountVolume(devicePath: string, owner: var): void {
        if (!devicePath || !devicePath.length)
            return;
        startJob("mount", qsTr("Mounting…"), fm(["mount", devicePath]), owner, "");
    }

    function openFile(path: string, owner: var): void {
        if (!path || !path.length)
            return;
        openFiles([path], owner);
    }

    function openFiles(paths: var, owner: var): void {
        if (!paths || !paths.length)
            return;
        const list = [];
        for (let i = 0; i < paths.length; ++i) {
            const p = String(paths[i] || "");
            if (p.length)
                list.push(p);
        }
        if (!list.length)
            return;
        openProc.owner = owner || null;
        openProc.command = fm(["open"].concat(list));
        openProc.running = true;
    }

    function importPaths(paths: var, destPath: string, owner: var): void {
        transferPaths(paths, destPath, false, owner);
    }

    function transferPaths(paths: var, destPath: string, move: bool, owner: var): void {
        if (!paths || !paths.length)
            return;
        const dest = destPath || home;
        const kind = move ? "move" : "copy";
        startJob(kind, move ? qsTr("Moving…") : qsTr("Copying…"), fm([kind, dest].concat(paths)), owner, "");
    }

    function undoMove(items: var, owner: var): void {
        if (!items || !items.length)
            return;
        const args = fm(["undo-move"]);
        for (let i = 0; i < items.length; ++i) {
            const it = items[i];
            if (!it || !it.to || !it.from)
                continue;
            args.push(String(it.to));
            args.push(String(it.from));
        }
        if (args.length <= 2)
            return;
        startJob("undo-move", qsTr("Undoing…"), args, owner, "");
    }

    function runQuick(command: list<string>, kind: string, renameAfter: string, owner: var): void {
        startJob(kind, kind === "mkdir" ? qsTr("Creating folder…") : qsTr("Working…"), command, owner, renameAfter || "");
    }

    function fetchInfo(paths: var, owner: var): void {
        if (!paths || !paths.length)
            return;
        infoProc.running = false;
        infoProc.owner = owner || null;
        infoProc.command = fm(["info"].concat(paths));
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
        command: [root.binary, "xdg-dirs"]
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
        command: [root.binary, "mounts"]
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
        property string jobId: ""

        stdout: SplitParser {
            onRead: line => {
                if (root.jobCancelRequested)
                    return;
                const raw = String(line || "").trim();
                if (!raw.length)
                    return;
                try {
                    const data = JSON.parse(raw);
                    if (data.type === "progress") {
                        const id = root.currentJobId || opProc.jobId;
                        if (data.message)
                            root.patchJob(id, {
                                progress: data.progress ?? 0,
                                label: data.message
                            });
                        else
                            root.patchJob(id, {
                                progress: data.progress ?? 0
                            });
                        return;
                    }

                    const owner = root.jobOwner;
                    const kind = opProc.kind;
                    const renameAfter = opProc.renameAfter;

                    if (data.ok === false || data.type === "error") {
                        root.notifyOwnerError(owner, data.error || qsTr("Operation failed"));
                        root.finishJob();
                        if (owner && owner.refresh)
                            owner.refresh();
                        return;
                    }

                    if (kind === "extract")
                        root.notifyOwner(owner, qsTr("Extracted"), data.result || "", "folder_zip");
                    else if (kind === "compress")
                        root.notifyOwner(owner, qsTr("Compressed"), data.result || "", "folder_zip");
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
                    if (renameAfter.length)
                        payload.renameAfter = renameAfter;

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

            if (root.jobCancelRequested) {
                const owner = root.jobOwner;
                root.jobCancelRequested = false;
                root.finishJob();
                root.notifyOwner(owner, qsTr("Cancelled"), qsTr("Operation cancelled"), "cancel");
                if (owner && owner.refresh)
                    owner.refresh();
                Qt.callLater(() => root.pumpQueue());
                return;
            }

            if (root.currentJobId.length && !root.jobSettled && opProc.jobId.length && opProc.jobId === root.currentJobId) {
                const owner = root.jobOwner;
                root.notifyOwnerError(owner, qsTr("Operation interrupted"));
                root.finishJob();
                if (owner && owner.refresh)
                    owner.refresh();
            }
            Qt.callLater(() => root.pumpQueue());
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
