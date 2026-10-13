pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.services.shell
import qs.config as Theme
import qs.utils
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root

    property int windowCount: 0
    property var latest: null
    readonly property var defaultApps: DefaultApps

    function openWindow(path: string): void {
        const start = (path && String(path).length) ? String(path) : FileManagerService.home;
        fmWindow.createObject(root, {
            startPath: start,
            pickerMode: false,
            pickerRequestId: ""
        });
        root.windowCount += 1;
        FileManagerService.openWindowCount += 1;
        FileManagerService.refreshMounts();
    }

    function openPicker(requestId: string): string {
        const id = String(requestId || "").trim();
        if (!id.length)
            return "{\"ok\":false,\"error\":\"missing request id\"}";
        fmWindow.createObject(root, {
            startPath: FileManagerService.home,
            pickerMode: true,
            pickerRequestId: id
        });
        root.windowCount += 1;
        FileManagerService.openWindowCount += 1;
        FileManagerService.refreshMounts();
        return "{\"ok\":true,\"id\":\"" + id + "\"}";
    }

    property string discImageRequestId: ""
    property bool discImageActive: false
    property int discImageTicks: 0

    function abortDiscImage(message: string): void {
        root.discImageActive = false;
        discPoll.stop();
        if (message && String(message).length)
            Toaster.toast(qsTr("Mount disc image"), message, "album", 3);
    }

    function mountDiscImage(): void {
        if (root.discImageActive)
            return;
        root.discImageRequestId = Date.now().toString(36) + Math.floor(Math.random() * 1e9).toString(36);
        root.discImageActive = true;
        root.discImageTicks = 0;
        discMkdir.exec(["mkdir", "-p", `${Paths.runtime}/${root.discImageRequestId}`]);
    }

    function consumeDiscImageResult(): void {
        if (!root.discImageActive)
            return;
        let data = null;
        try {
            data = JSON.parse(discResult.text() || "");
        } catch (e) {
            return;
        }
        if (!data || data.response === undefined || data.response === null)
            return;
        const response = Number(data.response);
        root.discImageActive = false;
        discPoll.stop();
        if (response !== 0)
            return;
        const uris = data.uris || [];
        if (!uris.length)
            return;
        let path = String(uris[0] || "");
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.slice("file://".length));
        if (!path.length)
            return;
        discLoop.exec(["udisksctl", "loop-setup", "--file", path, "--no-user-interaction"]);
    }

    Connections {
        target: FileManagerService

        function onMountDiscImageRequested(): void {
            root.mountDiscImage();
        }
    }

    Process {
        id: discMkdir

        onExited: code => {
            if (!root.discImageActive)
                return;
            if (code !== 0) {
                root.abortDiscImage(qsTr("Could not open the file chooser"));
                return;
            }
            discRequest.path = `${Paths.runtime}/${root.discImageRequestId}/request.json`;
            discRequest.setText(JSON.stringify({
                id: root.discImageRequestId,
                mode: "open",
                title: qsTr("Mount disc image"),
                acceptLabel: qsTr("Mount"),
                multiple: false,
                directory: false,
                currentFolder: FileManagerService.home,
                currentName: "",
                filters: [
                    {
                        name: qsTr("Disc images"),
                        patterns: ["*.iso", "*.img", "*.raw", "*.vhd", "*.vmdk", "*.qcow2"]
                    },
                    {
                        name: qsTr("All files"),
                        patterns: ["*"]
                    }
                ],
                files: []
            }));
        }
    }

    FileView {
        id: discRequest

        printErrors: false
        atomicWrites: true

        onSaved: {
            if (!root.discImageActive)
                return;
            root.openPicker(root.discImageRequestId);
            discResult.path = `${Paths.runtime}/${root.discImageRequestId}/result.json`;
            root.discImageTicks = 0;
            discPoll.start();
        }

        onSaveFailed: root.abortDiscImage(qsTr("Could not open the file chooser"))
    }

    FileView {
        id: discResult

        printErrors: false

        onLoaded: root.consumeDiscImageResult()
    }

    Timer {
        id: discPoll

        interval: 200
        repeat: true

        onTriggered: {
            if (!root.discImageActive) {
                stop();
                return;
            }
            root.discImageTicks += 1;
            if (root.discImageTicks > 3000) {
                root.abortDiscImage("");
                return;
            }
            discResult.reload();
        }
    }

    Process {
        id: discLoop

        stdout: StdioCollector {
            id: discLoopOut
        }
        stderr: StdioCollector {
            id: discLoopErr
        }

        onExited: code => {
            if (code === 0) {
                FileManagerService.refreshMounts();
                return;
            }
            const msg = String(discLoopErr.text || discLoopOut.text || "").trim();
            Toaster.toast(qsTr("Mount disc image"), msg.length ? msg : qsTr("Could not set up the disc image"), "album", 3);
        }
    }

    function hyprTitle(): string {
        const top = Hyprland.activeToplevel;
        if (!top)
            return "";
        const ipc = top.lastIpcObject || {};
        return String(top.title || ipc.title || "");
    }

    function isFmFocused(): bool {
        const title = root.hyprTitle();
        if (title.indexOf("Donwaztok") < 0)
            return false;
        return title.indexOf("Files") >= 0
            || title.indexOf("Open File") >= 0
            || title.indexOf("Select Folder") >= 0
            || title.indexOf("Save As") >= 0
            || title.indexOf("Save Files") >= 0;
    }

    function focusedContent(): var {
        const c = root.latest;
        if (c && c.isWindowActive)
            return c;
        return null;
    }

    function runMod(kind: string, held: bool): void {
        const c = root.focusedContent();
        if (!c || !root.isFmFocused())
            return;
        if (kind === "shift")
            c.setShiftHeld(held);
        else if (kind === "ctrl")
            c.setCtrlHeld(held);
    }

    function runNav(action: string): string {
        const c = root.focusedContent();
        if (!c || !root.isFmFocused())
            return root.statusJson();
        if (action === "back")
            c.shortcutBack();
        else if (action === "forward")
            c.shortcutForward();
        else if (action === "refresh")
            c.shortcutRefresh();
        return root.statusJson();
    }

    function runEdit(action: string): string {
        const c = root.focusedContent();
        if (!c || !root.isFmFocused())
            return root.statusJson();
        if (c.pickerMode)
            return root.statusJson();
        if (action === "cut")
            c.shortcutCut();
        else if (action === "copy")
            c.shortcutCopy();
        else if (action === "paste")
            c.shortcutPaste();
        else if (action === "delete")
            c.shortcutTrash();
        else if (action === "deletePermanent")
            c.shortcutDeletePermanent();
        else if (action === "undo")
            c.shortcutUndo();
        else if (action === "toggleHidden")
            c.shortcutToggleHidden();
        return root.statusJson();
    }

    function statusJson(): string {
        const c = root.latest;
        if (!c)
            return "{\"open\":false}";
        return JSON.stringify({
            open: true,
            path: c.currentPath,
            canGoBack: c.canGoBack,
            canGoForward: c.canGoForward,
            history: c.historyCount,
            lastInput: c.lastInput,
            qtActive: c.isWindowActive,
            hyprTitle: root.hyprTitle(),
            fmFocused: root.isFmFocused(),
            picker: !!c.pickerMode
        });
    }

    Component {
        id: fmWindow

        FloatingWindow {
            id: win

            property string startPath: FileManagerService.home
            property bool pickerMode: false
            property string pickerRequestId: ""

            title: content.pickerWindowTitle
            color: Colours.shellSurface
            implicitWidth: win.pickerMode ? 980 : 1100
            implicitHeight: win.pickerMode ? 640 : 720

            onVisibleChanged: {
                if (!visible)
                    win.destroy();
            }

            Component.onDestruction: {
                root.windowCount = Math.max(0, root.windowCount - 1);
                FileManagerService.openWindowCount = Math.max(0, FileManagerService.openWindowCount - 1);
                if (root.latest === content)
                    root.latest = null;
            }

            Behavior on color {
                CAnim {}
            }

            FileManagerContent {
                id: content
                anchors.fill: parent
                pickerMode: win.pickerMode
                pickerRequestId: win.pickerRequestId
                onRequestClose: win.destroy()
                onIsWindowActiveChanged: {
                    if (content.isWindowActive)
                        root.latest = content;
                }
                Component.onCompleted: {
                    root.latest = content;
                    if (win.pickerMode)
                        content.beginPicker(win.pickerRequestId);
                    else
                        content.openAt(win.startPath);
                }
            }
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerToggle"
        description: "Open Donwaztok file manager window"
        onPressed: root.openWindow("")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerBack"
        description: "File manager back"
        onPressed: root.runNav("back")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerForward"
        description: "File manager forward"
        onPressed: root.runNav("forward")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerCut"
        description: "File manager cut"
        onPressed: root.runEdit("cut")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerUndo"
        description: "File manager undo"
        onPressed: root.runEdit("undo")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerDeletePermanent"
        description: "File manager permanent delete"
        onPressed: root.runEdit("deletePermanent")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerToggleHidden"
        description: "File manager toggle hidden files"
        onPressed: root.runEdit("toggleHidden")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerRefresh"
        description: "File manager refresh"
        onPressed: root.runNav("refresh")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerShiftDown"
        description: "File manager shift pressed"
        onPressed: root.runMod("shift", true)
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerShiftUp"
        description: "File manager shift released"
        onPressed: root.runMod("shift", false)
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerCtrlDown"
        description: "File manager ctrl pressed"
        onPressed: root.runMod("ctrl", true)
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "fileManagerCtrlUp"
        description: "File manager ctrl released"
        onPressed: root.runMod("ctrl", false)
    }

    IpcHandler {
        target: "fileManager"

        function open(): void {
            root.openWindow("");
        }

        function openPath(path: string): void {
            const raw = String(path || "").trim();
            if (!raw.length || raw === "%f" || raw === "%F" || raw === "undefined")
                root.openWindow("");
            else
                root.openWindow(raw);
        }

        function toggle(): void {
            root.openWindow("");
        }

        function close(): void {}

        function pick(requestId: string): string {
            return root.openPicker(requestId);
        }

        function mountDiscImage(): string {
            root.mountDiscImage();
            return "{\"ok\":true}";
        }

        function status(): string {
            return root.statusJson();
        }

        function go(path: string): string {
            const c = root.latest;
            if (!c)
                return "{\"ok\":false}";
            c.navigateTo(path);
            return root.statusJson();
        }

        function back(): string {
            return root.runNav("back");
        }

        function forward(): string {
            return root.runNav("forward");
        }

        function cut(): string {
            return root.runEdit("cut");
        }

        function deletePermanent(): string {
            return root.runEdit("deletePermanent");
        }

        function refresh(): string {
            return root.runNav("refresh");
        }
    }
}
