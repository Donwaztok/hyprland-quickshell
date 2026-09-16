pragma ComponentBehavior: Bound

import qs.services.shell
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string currentPath: ""
    property var entries: []
    property var selectedPaths: []
    property bool showHidden: false
    property bool listView: true
    property string searchQuery: ""
    property string sortBy: "name" // name | size | mtime | type
    property bool sortAsc: true
    property bool busy: false
    property string renameTarget: ""
    property string renameDraft: ""
    property var toasts: []
    property int toastSeq: 0
    property var undoItems: []
    property string undoKind: "" // "trash" | "move"
    property string pendingEjectMount: ""
    property var history: []
    property var forwardHistory: []
    property bool pathEditing: false
    property string pathEditText: ""
    property bool suppressHistory: false

    readonly property bool appToastVisible: toasts.length > 0
    readonly property bool undoToastVisible: {
        const list = toasts;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].showUndo)
                return true;
        }
        return false;
    }

    readonly property bool isTrashView: currentPath === "trash://" || currentPath.startsWith("trash://")
    readonly property bool canGoBack: history.length > 0
    readonly property bool canGoForward: forwardHistory.length > 0

    readonly property var activeRemovableMount: {
        const path = currentPath;
        if (!path || path === "/" || isTrashView)
            return null;
        const mounts = FileManagerService.mounts;
        let best = null;
        for (let i = 0; i < mounts.length; ++i) {
            const m = mounts[i];
            if (!m || !m.mounted || !m.removable || !m.mount)
                continue;
            if (path === m.mount || path.startsWith(m.mount + "/")) {
                if (!best || m.mount.length > best.mount.length)
                    best = m;
            }
        }
        return best;
    }

    readonly property var filteredEntries: {
        const q = searchQuery.trim().toLowerCase();
        const src = q.length ? entries.filter(e => (e.name || "").toLowerCase().includes(q)) : entries;
        const list = src.slice();
        const key = sortBy || "name";
        const dir = sortAsc ? 1 : -1;
        list.sort((a, b) => {
            const aDir = !!(a && a.isDir);
            const bDir = !!(b && b.isDir);
            if (aDir !== bDir)
                return aDir ? -1 : 1;
            let cmp = 0;
            if (key === "size")
                cmp = (a.size || 0) - (b.size || 0);
            else if (key === "mtime")
                cmp = (a.mtime || 0) - (b.mtime || 0);
            else if (key === "type") {
                const ta = aDir ? "folder" : String(a.suffix || a.mimeType || "").toLowerCase();
                const tb = bDir ? "folder" : String(b.suffix || b.mimeType || "").toLowerCase();
                cmp = ta.localeCompare(tb);
            } else {
                cmp = String(a.name || "").localeCompare(String(b.name || ""), undefined, {
                    sensitivity: "base",
                    numeric: true
                });
            }
            if (cmp === 0) {
                cmp = String(a.name || "").localeCompare(String(b.name || ""), undefined, {
                    sensitivity: "base",
                    numeric: true
                });
            }
            return cmp * dir;
        });
        return list;
    }

    readonly property string activePlacePath: {
        let best = "";
        const path = currentPath;
        const lists = [FileManagerService.places, FileManagerService.pinnedPlaces];
        for (let li = 0; li < lists.length; ++li) {
            const places = lists[li];
            for (let i = 0; i < places.length; ++i) {
                const p = places[i].path;
                if (!p)
                    continue;
                if (path === p || path.startsWith(p.endsWith("/") ? p : p + "/")) {
                    if (p.length > best.length)
                        best = p;
                }
            }
        }
        return best;
    }

    readonly property real selectedBytes: {
        let total = 0;
        for (let i = 0; i < selectedPaths.length; ++i) {
            const entry = entries.find(e => e.path === selectedPaths[i]);
            if (entry && !entry.isDir)
                total += entry.size || 0;
        }
        return total;
    }

    readonly property int selectedDirCount: {
        let dirs = 0;
        for (let i = 0; i < selectedPaths.length; ++i) {
            const entry = entries.find(e => e.path === selectedPaths[i]);
            if (entry && entry.isDir)
                dirs += 1;
        }
        return dirs;
    }

    readonly property var currentMount: {
        let best = null;
        let bestLen = -1;
        const path = currentPath;
        const mounts = FileManagerService.mounts;
        for (let i = 0; i < mounts.length; ++i) {
            const m = mounts[i];
            const mp = m.mount;
            if (!mp)
                continue;
            if (path === mp || path.startsWith(mp.endsWith("/") ? mp : mp + "/")) {
                if (mp.length > bestLen) {
                    best = m;
                    bestLen = mp.length;
                }
            }
        }
        return best;
    }

    readonly property var pathCrumbs: {
        if (currentPath === "trash://" || currentPath.startsWith("trash://")) {
            return [
                {
                    label: "Trash",
                    path: "trash://"
                }
            ];
        }
        const homePrefix = FileManagerService.home;
        const rem = activeRemovableMount;
        if (rem && rem.mount) {
            const segs = [
                {
                    label: rem.name || rem.label || rem.mount.split("/").pop(),
                    path: rem.mount
                }
            ];
            if (currentPath !== rem.mount && currentPath.startsWith(rem.mount + "/")) {
                const rest = currentPath.slice(rem.mount.length + 1);
                const parts = rest.split("/").filter(p => p.length);
                let acc = rem.mount;
                for (let i = 0; i < parts.length; ++i) {
                    acc = `${acc}/${parts[i]}`;
                    segs.push({
                        label: parts[i],
                        path: acc
                    });
                }
            }
            return segs;
        }
        if (currentPath === homePrefix || currentPath.startsWith(homePrefix + "/")) {
            const segs = [
                {
                    label: "Home",
                    path: homePrefix
                }
            ];
            const rest = currentPath === homePrefix ? "" : currentPath.slice(homePrefix.length + 1);
            if (rest.length) {
                const parts = rest.split("/").filter(p => p.length);
                let acc = homePrefix;
                for (let i = 0; i < parts.length; ++i) {
                    acc = `${acc}/${parts[i]}`;
                    segs.push({
                        label: parts[i],
                        path: acc
                    });
                }
            }
            return segs;
        }
        // Absolute paths: skip a lone "/" crumb (avoids "/ / run / …")
        const segs = [];
        if (currentPath === "/") {
            segs.push({
                label: "/",
                path: "/"
            });
            return segs;
        }
        const parts = currentPath.split("/").filter(p => p.length);
        let acc = "";
        for (let i = 0; i < parts.length; ++i) {
            acc = `${acc}/${parts[i]}`;
            segs.push({
                label: parts[i],
                path: acc
            });
        }
        return segs;
    }

    function normalizePath(path: string): string {
        if (path === undefined || path === null)
            return "";
        let p = String(path).trim();
        if (!p.length || p === "undefined")
            return "";
        if (p === "trash://" || p.startsWith("trash://"))
            return "trash://";
        if (p.startsWith("file://"))
            p = p.slice("file://".length);
        if (p.startsWith("~")) {
            const home = FileManagerService.home || Quickshell.env("HOME") || "/";
            p = p === "~" ? home : (home + p.slice(1));
        }
        // Collapse duplicate slashes (keep leading slash)
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.endsWith("/"))
            p = p.replace(/\/+$/, "");
        return p.length ? p : "/";
    }

    function initAt(path: string): void {
        const fallback = FileManagerService.home || Quickshell.env("HOME") || "/";
        let target = fallback;
        if (path !== undefined && path !== null && String(path).length && String(path) !== "undefined")
            target = String(path);
        history = [];
        forwardHistory = [];
        suppressHistory = true;
        currentPath = normalizePath(target) || fallback;
        suppressHistory = false;
        pathEditing = false;
        refresh();
        FileManagerService.refreshMounts();
    }

    function refresh(): void {
        if (!currentPath.length || currentPath === "undefined")
            currentPath = FileManagerService.home || Quickshell.env("HOME") || "/";
        currentPath = normalizePath(currentPath) || currentPath;
        busy = true;
        const cmd = FileManagerService.fm(["list", currentPath].concat(showHidden ? ["--hidden"] : []));
        listProc.command = cmd;
        listProc.exec(cmd);
        startDirWatch();
    }

    function startDirWatch(): void {
        const target = isTrashView ? "trash://" : currentPath;
        if (!target.length || target === "undefined")
            return;
        if (watchProc.watchTarget === target && watchProc.running)
            return;
        watchProc.watchTarget = target;
        watchProc.exec(FileManagerService.fm(["watch", target]));
    }

    function applyListOutput(raw: string): void {
        busy = false;
        const text = String(raw || "").trim();
        if (!text.length)
            return;
        const lines = text.split("\n");
        let payload = "";
        for (let i = lines.length - 1; i >= 0; --i) {
            const line = lines[i].trim();
            if (line.startsWith("{")) {
                payload = line;
                break;
            }
        }
        if (!payload.length)
            return;
        try {
            const data = JSON.parse(payload);
            if (!data.ok) {
                if (String(data.error || "").includes("undefined") || !root.currentPath.length) {
                    root.currentPath = FileManagerService.home;
                    root.refresh();
                    return;
                }
                root.showAppToast(qsTr("Files"), data.error || qsTr("Failed to list folder"), "error");
                return;
            }
            root.entries = data.entries || [];
        } catch (e) {}
    }

    function navigate(path: string): void {
        if (path === undefined || path === null)
            return;
        const target = normalizePath(String(path));
        if (!target.length || target === "undefined")
            return;
        if (!suppressHistory && currentPath.length && currentPath !== target) {
            const nextHist = history.slice();
            nextHist.push(currentPath);
            if (nextHist.length > 64)
                nextHist.shift();
            history = nextHist;
            forwardHistory = [];
        }
        currentPath = target;
        selectedPaths = [];
        renameTarget = "";
        renameDraft = "";
        searchQuery = "";
        pathEditing = false;
        refresh();
    }

    function goBack(): void {
        if (!history.length)
            return;
        const nextHist = history.slice();
        const prev = nextHist.pop();
        history = nextHist;
        if (!prev)
            return;
        const nextFwd = forwardHistory.slice();
        if (currentPath.length) {
            nextFwd.push(currentPath);
            if (nextFwd.length > 64)
                nextFwd.shift();
            forwardHistory = nextFwd;
        }
        suppressHistory = true;
        navigate(prev);
        suppressHistory = false;
    }

    function goForward(): void {
        if (!forwardHistory.length)
            return;
        const nextFwd = forwardHistory.slice();
        const next = nextFwd.pop();
        forwardHistory = nextFwd;
        if (!next)
            return;
        const nextHist = history.slice();
        if (currentPath.length) {
            nextHist.push(currentPath);
            if (nextHist.length > 64)
                nextHist.shift();
            history = nextHist;
        }
        suppressHistory = true;
        navigate(next);
        suppressHistory = false;
    }

    function setSortBy(key: string): void {
        const next = key || "name";
        if (sortBy !== next) {
            sortBy = next;
            sortAsc = next === "name" || next === "type";
        }
    }

    function goUp(): void {
        if (currentPath === "trash://" || currentPath.startsWith("trash://")) {
            navigate(FileManagerService.home);
            return;
        }
        const path = normalizePath(currentPath);
        if (path === "/" || path === "")
            return;
        const rem = activeRemovableMount;
        if (rem && rem.mount && path === rem.mount) {
            navigate(FileManagerService.home);
            return;
        }
        const parts = path.split("/").filter(p => p.length);
        parts.pop();
        const parent = parts.length ? `/${parts.join("/")}` : "/";
        navigate(parent);
    }

    function beginPathEdit(): void {
        if (isTrashView)
            return;
        pathEditText = currentPath === "trash://" ? currentPath : normalizePath(currentPath);
        pathEditing = true;
    }

    function cancelPathEdit(): void {
        pathEditing = false;
        pathEditText = "";
    }

    function commitPathEdit(): void {
        const target = normalizePath(pathEditText);
        pathEditing = false;
        if (!target.length)
            return;
        navigate(target);
    }

    function isSelected(path: string): bool {
        return selectedPaths.indexOf(path) >= 0;
    }

    function isMarkedCut(path: string): bool {
        if (FileManagerService.clipboardMode !== "cut")
            return false;
        const list = FileManagerService.clipboardPaths;
        return !!(list && list.indexOf(path) >= 0);
    }

    property string selectAnchor: ""

    function selectOnly(path: string): void {
        selectedPaths = [path];
        selectAnchor = path;
    }

    function toggleSelect(path: string): void {
        const next = [];
        let found = false;
        for (let i = 0; i < selectedPaths.length; ++i) {
            if (selectedPaths[i] === path)
                found = true;
            else
                next.push(selectedPaths[i]);
        }
        if (!found)
            next.push(path);
        selectedPaths = next;
        selectAnchor = path;
    }

    function selectRange(path: string): void {
        if (!selectAnchor.length) {
            selectOnly(path);
            return;
        }
        const list = filteredEntries;
        let i0 = -1;
        let i1 = -1;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].path === selectAnchor)
                i0 = i;
            if (list[i].path === path)
                i1 = i;
        }
        if (i0 < 0 || i1 < 0) {
            selectOnly(path);
            return;
        }
        if (i0 > i1) {
            const tmp = i0;
            i0 = i1;
            i1 = tmp;
        }
        const next = [];
        for (let i = i0; i <= i1; ++i)
            next.push(list[i].path);
        selectedPaths = next;
    }

    function applyMarqueeSelection(paths: var, additive: bool, base: var): void {
        const src = paths || [];
        if (!additive) {
            selectedPaths = src.slice();
            if (src.length)
                selectAnchor = src[src.length - 1];
            return;
        }
        const seen = {};
        const next = [];
        const from = base || [];
        for (let i = 0; i < from.length; ++i) {
            const p = from[i];
            if (!seen[p]) {
                seen[p] = true;
                next.push(p);
            }
        }
        for (let i = 0; i < src.length; ++i) {
            const p = src[i];
            if (!seen[p]) {
                seen[p] = true;
                next.push(p);
            }
        }
        selectedPaths = next;
        if (src.length)
            selectAnchor = src[src.length - 1];
    }

    function selectAll(): void {
        selectedPaths = filteredEntries.map(e => e.path);
        if (selectedPaths.length)
            selectAnchor = selectedPaths[selectedPaths.length - 1];
    }

    function clearSelection(): void {
        selectedPaths = [];
    }

    function openEntry(entry: var): void {
        if (!entry)
            return;
        if (isTrashView) {
            if (entry.trashUri)
                FileManagerService.restoreTrash([entry.trashUri], root);
            return;
        }
        if (entry.isDir) {
            navigate(entry.path);
            return;
        }
        if (entry.isArchive) {
            FileManagerService.smartExtract(entry.path, currentPath, root);
            return;
        }
        FileManagerService.openFile(entry.path, root);
    }

    /** Open / extract / restore every selected item (Enter on multi-select). */
    function openSelection(): void {
        if (!selectedPaths.length)
            return;

        if (isTrashView) {
            const uris = [];
            for (let i = 0; i < selectedPaths.length; ++i) {
                const e = entries.find(x => x.path === selectedPaths[i]);
                if (e && e.trashUri)
                    uris.push(e.trashUri);
            }
            if (uris.length)
                FileManagerService.restoreTrash(uris, root);
            return;
        }

        if (selectedPaths.length === 1) {
            const only = entries.find(e => e.path === selectedPaths[0]);
            if (only)
                openEntry(only);
            return;
        }

        const selected = [];
        for (let i = 0; i < selectedPaths.length; ++i) {
            const e = entries.find(x => x.path === selectedPaths[i]);
            if (e)
                selected.push(e);
        }
        if (!selected.length)
            return;

        const dirs = selected.filter(e => e.isDir);
        const files = selected.filter(e => !e.isDir);

        // Only folders selected → enter the first one
        if (!files.length) {
            if (dirs.length)
                navigate(dirs[0].path);
            return;
        }

        const archives = [];
        const toOpen = [];
        for (let i = 0; i < files.length; ++i) {
            const f = files[i];
            if (f.isArchive)
                archives.push(f.path);
            else
                toOpen.push(f.path);
        }

        for (let i = 0; i < archives.length; ++i)
            FileManagerService.smartExtract(archives[i], currentPath, root);

        if (toOpen.length)
            FileManagerService.openFiles(toOpen, root);
    }

    function uriListForDrag(primaryPath: string): string {
        let paths = [];
        if (primaryPath && selectedPaths.indexOf(primaryPath) >= 0 && selectedPaths.length)
            paths = selectedPaths.slice();
        else if (primaryPath)
            paths = [primaryPath];
        // RFC 2483 uri-list uses CRLF so multi-item drops parse as separate URLs
        return paths.map(p => "file://" + p).join("\r\n");
    }

    function importDroppedUrls(urls: var, forceCopy: bool, destPath: string): void {
        if (isTrashView || !urls || !urls.length)
            return;
        const paths = [];
        const seen = {};
        const pushPath = raw => {
            const p = FileManagerService.normalizeFsPath(String(raw || ""));
            if (!p.length || p.startsWith("trash://") || seen[p])
                return;
            seen[p] = true;
            paths.push(p);
        };
        for (let i = 0; i < urls.length; ++i) {
            const u = String(urls[i] || "");
            if (!u.length)
                continue;
            // One mime string may still carry several URIs
            const parts = u.split(/\r?\n/);
            for (let j = 0; j < parts.length; ++j) {
                const part = String(parts[j] || "").trim();
                if (!part.length || part.startsWith("#"))
                    continue;
                pushPath(part);
            }
        }
        if (!paths.length)
            return;

        const dest = FileManagerService.normalizeFsPath(destPath.length ? destPath : currentPath);
        if (!dest.length)
            return;

        // Dropping onto one of the dragged items (e.g. a selected folder) is a no-op
        if (paths.indexOf(dest) >= 0)
            return;

        const transferable = [];
        for (let i = 0; i < paths.length; ++i) {
            const p = paths[i];
            if (p === dest || dest.startsWith(p + "/"))
                continue; // don't drop a folder into itself / descendant
            const slash = p.lastIndexOf("/");
            const parent = slash <= 0 ? "/" : p.slice(0, slash);
            if (parent === dest)
                continue; // already in this folder — no copy/move
            transferable.push(p);
        }
        if (!transferable.length)
            return;

        const doCopy = !!forceCopy;
        FileManagerService.transferPaths(transferable, dest, !doCopy, root);
    }

    function copySelection(): void {
        if (!selectedPaths.length)
            return;
        FileManagerService.clipboardMode = "copy";
        FileManagerService.clipboardPaths = selectedPaths.slice();
        showAppToast(qsTr("Copied"), qsTr("Copied %1 item(s)").arg(selectedPaths.length), "content_copy");
    }

    function cutSelection(): void {
        if (!selectedPaths.length)
            return;
        FileManagerService.clipboardMode = "cut";
        FileManagerService.clipboardPaths = selectedPaths.slice();
        showAppToast(qsTr("Cut"), qsTr("Cut %1 item(s)").arg(selectedPaths.length), "content_cut");
    }

    function pasteClipboard(): void {
        FileManagerService.pasteClipboard(currentPath, root);
    }

    function trashSelection(): void {
        if (!selectedPaths.length)
            return;
        if (isTrashView) {
            // Already in trash — permanent delete needs confirmation from UI.
            return;
        }
        FileManagerService.trashSelection(selectedPaths, root);
    }

    function deletePermanentSelection(): void {
        if (!selectedPaths.length)
            return;
        FileManagerService.deletePermanent(selectedPaths, root);
    }

    function emptyTrash(): void {
        if (!isTrashView)
            return;
        FileManagerService.emptyTrash(root);
    }

    function toastTypeForIcon(icon: string): int {
        if (icon === "error")
            return 3;
        if (icon === "warning")
            return 2;
        if (icon === "delete" || icon === "delete_forever" || icon === "delete_sweep")
            return 2;
        if (icon === "check_circle" || icon === "check_circle_unread" || icon === "content_copy" || icon === "content_cut" || icon === "undo" || icon === "folder_zip")
            return 1;
        return 0;
    }

    function upsertToast(opts: var): string {
        const spec = opts || {};
        const key = spec.key ? String(spec.key) : "";
        let list = [];
        for (let i = 0; i < toasts.length; ++i) {
            if (!key || toasts[i].key !== key)
                list.push(toasts[i]);
        }
        toastSeq += 1;
        const icon = spec.icon || "info";
        let lane = spec.lane || "";
        if (!lane.length) {
            if (key === "status")
                lane = "info";
            else if (spec.showProgress)
                lane = "progress";
            else
                lane = "timed";
        }
        const item = {
            id: "t" + toastSeq,
            key: key,
            lane: lane,
            title: spec.title || "",
            message: spec.message || "",
            icon: icon,
            type: spec.type !== undefined && spec.type !== null ? spec.type : toastTypeForIcon(icon),
            progress: spec.progress !== undefined ? spec.progress : -1,
            showProgress: !!spec.showProgress,
            showUndo: !!spec.showUndo,
            timeout: spec.timeout !== undefined ? spec.timeout : (lane === "timed" ? 4000 : 2800)
        };
        toasts = list.concat([item]).slice(-8);
        return item.id;
    }

    function dismissToast(id: string): void {
        const next = toasts.filter(t => t.id !== id);
        if (next.length === toasts.length)
            return;
        toasts = next;
    }

    function dismissByKey(key: string): void {
        const next = toasts.filter(t => t.key !== key);
        if (next.length === toasts.length)
            return;
        toasts = next;
    }

    function showAppToast(title: string, message: string, icon: string): void {
        upsertToast({
            title: title || "",
            message: message || "",
            icon: icon || "info",
            lane: "timed",
            timeout: 4000
        });
    }

    function showUndoToast(kind: string, items: var, count: int): void {
        undoKind = kind || "trash";
        undoItems = items || [];
        const isTrash = undoKind === "trash";
        upsertToast({
            key: "undo",
            lane: "timed",
            title: isTrash ? qsTr("Moved to Trash") : qsTr("Moved"),
            message: qsTr("%1 item(s)").arg(count || undoItems.length || 0),
            icon: isTrash ? "delete" : "drive_file_move",
            type: isTrash ? 2 : 1,
            showUndo: true,
            timeout: 8000
        });
    }

    function dismissUndoToast(): void {
        dismissByKey("undo");
        undoItems = [];
        undoKind = "";
    }

    function dismissAppToast(): void {
        const list = toasts;
        for (let i = list.length - 1; i >= 0; --i) {
            const t = list[i];
            if (!t || t.lane === "info")
                continue;
            if (t.showUndo)
                dismissUndoToast();
            else
                dismissToast(t.id);
            return;
        }
    }

    function canUndo(): bool {
        return undoKind.length > 0 && undoItems.length > 0;
    }

    function undoLast(): void {
        if (!canUndo())
            return;
        if (undoKind === "move")
            undoMove();
        else
            undoTrash();
    }

    function undoTrash(): void {
        const specs = [];
        for (let i = 0; i < undoItems.length; ++i) {
            const it = undoItems[i];
            if (!it)
                continue;
            if (it.uri)
                specs.push(it.uri);
            else if (it.trashName)
                specs.push("trash:///" + it.trashName);
            else if (it.original)
                specs.push(it.original);
        }
        dismissUndoToast();
        if (specs.length)
            FileManagerService.restoreTrash(specs, root);
    }

    function undoMove(): void {
        const items = undoItems.slice();
        dismissUndoToast();
        if (items.length)
            FileManagerService.undoMove(items, root);
    }

    function mkdir(): void {
        if (isTrashView)
            return;
        let name = qsTr("New Folder");
        let path = `${currentPath}/${name}`;
        let n = 1;
        const names = new Set(entries.map(e => e.name));
        while (names.has(name)) {
            n += 1;
            name = qsTr("New Folder (%1)").arg(n);
            path = `${currentPath}/${name}`;
        }
        FileManagerService.runQuick(FileManagerService.fm(["mkdir", path]), "mkdir", path, root);
    }

    function beginRename(path: string): void {
        if (isTrashView)
            return;
        const target = path || (selectedPaths.length === 1 ? selectedPaths[0] : "");
        if (!target.length)
            return;
        renameTarget = target;
        const slash = target.lastIndexOf("/");
        renameDraft = slash >= 0 ? target.slice(slash + 1) : target;
    }

    function commitRename(newName: string): void {
        const name = String(newName || renameDraft || "").trim();
        if (!renameTarget.length || !name.length) {
            renameTarget = "";
            renameDraft = "";
            return;
        }
        if (name.includes("/") || name === "." || name === "..") {
            showAppToast(qsTr("Rename"), qsTr("Invalid name"), "error");
            return;
        }
        const parent = renameTarget.substring(0, renameTarget.lastIndexOf("/")) || "/";
        const dst = parent === "/" ? `/${name}` : `${parent}/${name}`;
        if (dst === renameTarget) {
            renameTarget = "";
            renameDraft = "";
            return;
        }
        const src = renameTarget;
        renameTarget = "";
        renameDraft = "";
        FileManagerService.runQuick(FileManagerService.fm(["rename", src, dst]), "rename", "", root);
    }

    function cancelRename(): void {
        renameTarget = "";
        renameDraft = "";
    }

    function openTerminal(): void {
        Quickshell.execDetached(["kitty", "--working-directory", currentPath]);
    }

    function leaveMount(mountPath: string): void {
        if (!mountPath || !mountPath.length)
            return;
        listProc.running = false;
        // Drop entries immediately so thumbnail Image loaders release file handles
        if (currentPath === mountPath || currentPath.startsWith(mountPath + "/")) {
            entries = [];
            selectedPaths = [];
            renameTarget = "";
            renameDraft = "";
            currentPath = FileManagerService.home;
            refresh();
        }
    }

    function requestEject(mountPath: string): void {
        if (!mountPath || !mountPath.length)
            return;
        leaveMount(mountPath);
        pendingEjectMount = mountPath;
        ejectDelay.restart();
    }

    function mountAndOpen(devicePath: string): void {
        if (!devicePath || !devicePath.length)
            return;
        FileManagerService.mountVolume(devicePath, root);
    }

    function onJobDone(kind: string, data: var): void {
        if (kind === "extract") {
            if (data && data.isDir && data.result)
                navigate(data.result);
            else {
                refresh();
                if (data && data.result)
                    selectOnly(data.result);
            }
        } else if (kind === "compress") {
            refresh();
            if (data && data.result)
                selectOnly(data.result);
        } else if (kind === "trash") {
            selectedPaths = [];
            refresh();
            showUndoToast("trash", data?.items || [], data?.count || 0);
        } else if (kind === "move") {
            selectedPaths = [];
            refresh();
            const items = data?.items || [];
            if (items.length)
                showUndoToast("move", items, data?.count || items.length);
        } else if (kind === "undo-move" || kind === "delete" || kind === "restore" || kind === "empty-trash") {
            selectedPaths = [];
            refresh();
        } else if (kind === "eject") {
            const ejected = data?.mount || "";
            if (ejected.length && (currentPath === ejected || currentPath.startsWith(ejected + "/")))
                navigate(FileManagerService.home);
            FileManagerService.refreshMounts();
        } else if (kind === "mount") {
            const mp = data?.mount || "";
            if (mp.length)
                navigate(mp);
            FileManagerService.refreshMounts();
        } else if (kind === "mkdir") {
            refresh();
            const renamePath = (data && (data.renameAfter || data.path)) || "";
            if (renamePath.length)
                beginRename(renamePath);
        } else {
            refresh();
        }
        FileManagerService.refreshMounts();
    }

    Timer {
        id: ejectDelay
        interval: 550
        repeat: false
        onTriggered: {
            const mp = root.pendingEjectMount;
            root.pendingEjectMount = "";
            if (mp.length)
                FileManagerService.ejectVolume(mp, root);
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (listProc.running)
                    return;
                root.applyListOutput(text);
            }
        }
    }

    Process {
        id: watchProc
        property string watchTarget: ""
        stdout: SplitParser {
            onRead: line => {
                if (String(line).indexOf("\"change\"") < 0)
                    return;
                dirWatchDebounce.restart();
            }
        }
        onExited: {
            if (watchProc.watchTarget.length)
                watchRestart.restart();
        }
    }

    Timer {
        id: dirWatchDebounce
        interval: 280
        repeat: false
        onTriggered: {
            if (root.renameTarget.length) {
                restart();
                return;
            }
            root.refresh();
        }
    }

    Timer {
        id: watchRestart
        interval: 800
        repeat: false
        onTriggered: {
            if (watchProc.watchTarget.length && !watchProc.running)
                root.startDirWatch();
        }
    }
}
