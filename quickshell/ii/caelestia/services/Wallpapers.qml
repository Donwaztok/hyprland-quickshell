pragma Singleton

import caelestia.config
import caelestia.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: Config.services.smartScheme ? [] : ["--no-smart"]

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock

    function setWallpaper(path: string): void {
        actualCurrent = path;
        if (CaelestiaCli.available) {
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
            return;
        }
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", path, root.currentNamePath]);
        const cmd = (Config.services.wallpaperSetCommand || "").trim();
        if (cmd.length > 0) {
            const safePath = path.replace(/'/g, "'\"'\"'");
            Quickshell.execDetached(["sh", "-c", cmd.replace(/%s/g, "'" + safePath + "'")]);
        }
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
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

    FileView {
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.actualCurrent = text().trim();
            root.previewColourLock = false;
        }
        onLoadFailed: () => {
            root.actualCurrent = "";
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: 1  // Images
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
