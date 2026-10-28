pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property var windows: []

    function openWindow(path: string): void {
        viewerWindow.createObject(root, {
            startPath: TextEditorService.normalizePath(path)
        });
    }

    function untrack(win: var): void {
        root.windows = root.windows.filter(w => w && w !== win);
    }

    Component {
        id: viewerWindow

        FloatingWindow {
            id: win

            property string startPath: ""

            title: content.windowTitle
            color: Colours.shellSurface
            implicitWidth: 1000
            implicitHeight: 680

            onVisibleChanged: {
                if (!visible)
                    win.destroy();
            }

            Component.onCompleted: root.windows = root.windows.concat([win])
            Component.onDestruction: root.untrack(win)

            Behavior on color {
                CAnim {}
            }

            MediaViewerContent {
                id: content
                anchors.fill: parent
                filePath: win.startPath
                onRequestClose: win.destroy()
            }
        }
    }

    IpcHandler {
        target: "mediaViewer"

        function open(path: string): void {
            const raw = String(path || "").trim();
            if (raw.length && raw !== "%f" && raw !== "%F" && raw !== "undefined")
                root.openWindow(raw);
        }

        function close(): void {
            const w = root.windows[root.windows.length - 1];
            if (w)
                w.destroy();
        }
    }
}
