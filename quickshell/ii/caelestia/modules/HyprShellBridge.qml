import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import caelestia.config
import caelestia.services

// Hypr global shortcuts + IPC targets previously registered by removed ii panels
// (Overview, Bar, VerticalBar, sidebars). Maps behaviour to Caelestia drawers + GlobalStates.
Scope {
    id: bridge
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen === 2) ?? false

    function vis(): var {
        return Visibilities.getForActive();
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }

        function close(): void {
            GlobalStates.barOpen = false;
        }

        function open(): void {
            GlobalStates.barOpen = true;
        }
    }

    GlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"

        onPressed: {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }
    }

    GlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"

        onPressed: {
            GlobalStates.barOpen = true;
        }
    }

    GlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"

        onPressed: {
            GlobalStates.barOpen = false;
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.sidebar = !v.sidebar;
        }

        function close(): void {
            const v = vis();
            if (v)
                v.sidebar = false;
        }

        function open(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.sidebar = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.sidebar = !v.sidebar;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.sidebar = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"

        onPressed: {
            const v = vis();
            if (v)
                v.sidebar = false;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggleDetach"
        description: "Detach left sidebar (no-op with Caelestia drawers)"

        onPressed: {}
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.utilities = !v.utilities;
        }

        function close(): void {
            const v = vis();
            if (v)
                v.utilities = false;
        }

        function open(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.utilities = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.utilities = !v.utilities;
        }
    }

    IpcHandler {
        target: "search"

        function toggle(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.launcher = !v.launcher;
        }

        function workspacesToggle(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.dashboard = !v.dashboard;
        }

        function close(): void {
            const v = vis();
            if (!v)
                return;
            v.launcher = false;
            v.dashboard = false;
        }

        function open(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.launcher = true;
        }

        function toggleReleaseInterrupt(): void {
            GlobalStates.superReleaseMightTrigger = false;
        }

        function clipboardToggle(): void {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            Config.launcher.pendingOpenPrefix = Config.launcher.clipboardPrefix;
            v.launcher = true;
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.launcher = !v.launcher;
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            const v = vis();
            if (v)
                v.dashboard = false;
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.dashboard = !v.dashboard;
        }
    }

    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            v.launcher = !v.launcher;
        }
    }

    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }

    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on launcher"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            Config.launcher.pendingOpenPrefix = Config.launcher.clipboardPrefix;
            v.launcher = true;
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on launcher"

        onPressed: {
            const v = vis();
            if (!v || bridge.hasFullscreen)
                return;
            Config.launcher.pendingOpenPrefix = ":";
            v.launcher = true;
        }
    }
}
