pragma Singleton

import caelestia.config
import caelestia.utils
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: Config.services.smartScheme ? [] : ["--no-smart"]

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock

    function persistWallpaperPath(path: string): void {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"", "sh", path, root.currentNamePath]);
    }

    function firstImageEntry(): var {
        if (wallpaperScanResults.length > 0)
            return wallpaperScanResults[0];
        return null;
    }

    function refreshWallpaperScanResults(): void {
        const prev = [];
        for (let j = 0; j < wallpaperScanResults.length; ++j)
            prev.push(wallpaperScanResults[j]);
        wallpaperScanResults = [];
        for (let k = 0; k < prev.length; ++k) {
            const o = prev[k];
            if (o)
                o.destroy();
        }
        const out = [];
        for (let i = 0; i < wallpaperDirModel.count; ++i) {
            let p = wallpaperDirModel.get(i, "filePath");
            if (!p || !p.length) {
                const u = wallpaperDirModel.get(i, "fileUrl");
                p = u ? String(u).replace(/^file:\/\//, "") : "";
            }
            const name = wallpaperDirModel.get(i, "fileName") || "";
            if (!p || !p.length)
                continue;
            const e = wallpaperEntryFactory.createObject(root, {
                path: p,
                relativePath: name.length ? name : p.split("/").pop(),
                isDir: false,
                isImage: true
            });
            out.push(e);
        }
        wallpaperScanResults = out;
    }

    /// Same directory as Caelestia config (paths.wallpaperDir), with sane fallbacks.
    readonly property url wallpaperDirUrl: {
        let p = String(Paths.wallsdir || `${Paths.home}/Pictures/Wallpapers`).trim();
        if (p.startsWith("file:"))
            return Qt.resolvedUrl(p);
        p = p.replace(/^~(?=\/)/, Paths.home);
        if (!p.startsWith("/"))
            p = `${Paths.home}/${p}`;
        return Qt.resolvedUrl("file://" + p);
    }

    property list<QtObject> wallpaperScanResults: []

    /// Without Caelestia CLI: optional user command, else hyprctl+hyprpaper per monitor when available.
    function applyCompositorWallpaper(path: string): void {
        const cmd = (Config.services.wallpaperSetCommand || "").trim();
        if (cmd.length > 0) {
            const safePath = path.replace(/'/g, "'\"'\"'");
            Quickshell.execDetached(["sh", "-c", cmd.replace(/%s/g, "'" + safePath + "'")]);
            return;
        }
        const vals = Hyprland.monitors.values;
        if (!vals || vals.length === 0)
            return;
        Quickshell.execDetached(["hyprctl", "hyprpaper", "preload", path]);
        for (const m of vals)
            Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${m.name},${path}`]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        if (CaelestiaCli.available) {
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
            return;
        }
        persistWallpaperPath(path);
        applyCompositorWallpaper(path);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic" && CaelestiaCli.available)
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    /// Used so launcher bindings re-run when FolderListModel finishes loading (see WallpaperList).
    readonly property int wallpaperImageCount: wallpaperDirModel.count

    list: wallpaperScanResults
    key: "relativePath"
    useFuzzy: Config.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }
    }

    Component {
        id: wallpaperEntryFactory

        FileSystemEntry {}
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.actualCurrent = text().trim();
            root.previewColourLock = false;
            if (root.actualCurrent.length === 0)
                defaultPickTimer.start();
        }
        onLoadFailed: () => {
            root.actualCurrent = "";
            defaultPickTimer.start();
        }
    }

    FolderListModel {
        id: wallpaperDirModel

        folder: root.wallpaperDirUrl
        showDirs: false
        showDotAndDotDot: false
        showOnlyReadable: true
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.bmp", "*.svg"]
        sortField: FolderListModel.Name

        onCountChanged: root.refreshWallpaperScanResults()
        onFolderChanged: root.refreshWallpaperScanResults()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.refreshWallpaperScanResults();
        }

        Component.onCompleted: Qt.callLater(() => root.refreshWallpaperScanResults())
    }

    Timer {
        id: defaultPickTimer

        interval: 120
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (root.actualCurrent.length > 0) {
                stop();
                return;
            }
            if (!Config.loaded && attempts < 80)
                return;

            const entry = root.firstImageEntry();
            if (entry) {
                root.setWallpaper(entry.path);
                stop();
                return;
            }
            if (attempts >= 80)
                stop();
        }
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
