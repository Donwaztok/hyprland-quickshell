pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root

    property var windows: []

    function openWindow(path: string): void {
        const start = TextEditorService.normalizePath(path);
        if (start.length) {
            const list = root.windows;
            for (let i = 0; i < list.length; ++i) {
                const w = list[i];
                if (w && w.filePath === start) {
                    w.visible = true;
                    root.focusWindow(w);
                    return;
                }
            }
        }
        editorWindow.createObject(root, {
            startPath: start
        });
    }

    function focusWindow(win: var): void {
        if (!win)
            return;
        const title = String(win.title || "");
        if (!title.length)
            return;
        const escaped = title.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
        Hyprland.dispatch(`focuswindow title:^(${escaped})$`);
    }

    function track(win: var): void {
        const next = [];
        const list = root.windows;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i] !== win)
                next.push(list[i]);
        }
        next.push(win);
        root.windows = next;
    }

    function untrack(win: var): void {
        const next = [];
        const list = root.windows;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i] !== win)
                next.push(list[i]);
        }
        root.windows = next;
    }

    function hyprTitle(): string {
        const top = Hyprland.activeToplevel;
        if (!top)
            return "";
        const ipc = top.lastIpcObject || {};
        return String(top.title || ipc.title || "");
    }

    function isEditorFocused(): bool {
        return root.hyprTitle().indexOf(" — Text") >= 0;
    }

    function focusedWindow(): var {
        const title = root.hyprTitle();
        const list = root.windows;
        for (let i = 0; i < list.length; ++i) {
            const w = list[i];
            if (w && String(w.title || "") === title)
                return w;
        }
        if (list.length)
            return list[list.length - 1];
        return null;
    }

    function openFind(): void {
        const list = root.windows;
        let target = null;
        for (let i = 0; i < list.length; ++i) {
            const w = list[i];
            if (w && w.active) {
                target = w;
                break;
            }
        }
        if (!target && root.isEditorFocused())
            target = root.focusedWindow();
        if (target)
            target.openFind();
    }

    Connections {
        target: TextEditorService
        function onRequestOpen(path: string): void {
            root.openWindow(path);
        }
    }

    Component {
        id: editorWindow

        FloatingWindow {
            id: win

            property string startPath: ""
            property alias filePath: content.filePath
            property bool allowDestroy: false

            title: content.windowTitle
            color: Colours.shellSurface
            implicitWidth: 900
            implicitHeight: 640

            onVisibleChanged: {
                if (visible)
                    return;
                if (win.allowDestroy || !content.dirty) {
                    win.destroy();
                    return;
                }
                win.visible = true;
                content.askClose();
            }

            Component.onCompleted: root.track(win)
            Component.onDestruction: root.untrack(win)

            function destroyNow(): void {
                win.allowDestroy = true;
                win.destroy();
            }

            function openFind(): void {
                content.openFind();
            }

            Behavior on color {
                CAnim {}
            }

            TextEditorContent {
                id: content
                anchors.fill: parent
                startPath: win.startPath
                onRequestClose: {
                    if (content.dirty)
                        content.askClose();
                    else
                        win.destroyNow();
                }
                onRequestForceClose: win.destroyNow()
            }
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "textEditorToggle"
        description: "Open Donwaztok text editor"
        onPressed: root.openWindow("")
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "textEditorFind"
        description: "Text editor find"
        onPressed: root.openFind()
    }

    IpcHandler {
        target: "textEditor"

        function open(path: string): void {
            const raw = String(path || "").trim();
            if (!raw.length || raw === "%f" || raw === "%F" || raw === "undefined")
                root.openWindow("");
            else
                root.openWindow(raw);
        }

        function toggle(): void {
            root.openWindow("");
        }

        function find(): void {
            root.openFind();
        }

        function status(): string {
            const list = root.windows;
            const wins = [];
            for (let i = 0; i < list.length; ++i) {
                const w = list[i];
                if (!w)
                    continue;
                wins.push({
                    title: String(w.title || ""),
                    active: !!w.active,
                    visible: !!w.visible
                });
            }
            return JSON.stringify({
                hyprTitle: root.hyprTitle(),
                editorFocused: root.isEditorFocused(),
                windows: wins
            });
        }
    }
}
