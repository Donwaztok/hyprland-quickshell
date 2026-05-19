import qs.components.misc
import qs.config
import qs.services.shell
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen === 2) ?? false

    CustomShortcut {
        name: "controlCenter"
        description: "Open control center"
        onPressed: Visibilities.openControlCenter("")
    }

    CustomShortcut {
        name: "showall"
        description: "Toggle launcher, dashboard and utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            const open = !(v.launcher || v.dashboard || v.utilities);
            if (open)
                Visibilities.closeLauncherExcept(Hypr.focusedMonitor);
            v.launcher = v.dashboard = v.utilities = open;
        }
    }

    CustomShortcut {
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.dashboard = !visibilities.dashboard;
        }
    }

    CustomShortcut {
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.session = !visibilities.session;
        }
    }

    CustomShortcut {
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen)
                Visibilities.toggleLauncher();
            root.launcherInterrupted = false;
        }
    }

    CustomShortcut {
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    CustomShortcut {
        name: "launcherOpenClipboard"
        description: "Open launcher with clipboard history"
        onReleased: {
            if (root.hasFullscreen)
                return;
            Visibilities.openLauncher(Config.launcher.clipboardPrefix);
        }
    }

    CustomShortcut {
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.sidebar = !visibilities.sidebar;
        }
    }

    CustomShortcut {
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.utilities = !visibilities.utilities;
        }
    }

    IpcHandler {
        target: "launcher"

        function openClipboard(): void {
            if (root.hasFullscreen)
                return;
            Visibilities.openLauncher(Config.launcher.clipboardPrefix);
        }
    }

    IpcHandler {
        target: "drawers"

        function open(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                if (drawer === "launcher")
                    Visibilities.openLauncher();
                else
                    Visibilities.getForActive()[drawer] = true;
            } else {
                console.warn(`[IPC] Drawer "${drawer}" does not exist`);
            }
        }

        function close(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                const visibilities = Visibilities.getForActive();
                visibilities[drawer] = false;
            } else {
                console.warn(`[IPC] Drawer "${drawer}" does not exist`);
            }
        }

        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                if (drawer === "launcher")
                    Visibilities.toggleLauncher();
                else {
                    const visibilities = Visibilities.getForActive();
                    visibilities[drawer] = !visibilities[drawer];
                }
            } else {
                console.warn(`[IPC] Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }
    }

    IpcHandler {
        target: "controlCenter"

        function open(): void {
            Visibilities.openControlCenter("");
        }
    }

    IpcHandler {
        target: "toaster"

        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }
    }
}
