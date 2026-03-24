import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import caelestia.config as CaelestiaCfg
import caelestia.services
import caelestia.utils

/**
 * Replaces the ii WallpaperSelector panel: Hyprland globals quickshell:wallpaperSelectorToggle /
 * wallpaperSelectorRandom and IPC wallpaperSelector now drive the Caelestia launcher / wallpaper flow.
 */
Scope {
    function toggleLauncherWallpaper(): void {
        if (!CaelestiaCfg.Config.loaded)
            return;
        const v = Visibilities.getForActive();
        if (!v)
            return;
        if (v.launcher) {
            v.launcher = false;
            return;
        }
        CaelestiaCfg.Config.launcher.pendingOpenPrefix = `${CaelestiaCfg.Config.launcher.actionPrefix}wallpaper`;
        v.launcher = true;
    }

    function pickRandomWallpaper(): void {
        if (CaelestiaCli.available) {
            CaelestiaCli.exec(["wallpaper", "-r"]);
            return;
        }
        const list = Wallpapers.list;
        if (!list || list.length === 0)
            return;
        const i = Math.floor(Math.random() * list.length);
        const path = list[i]?.path;
        if (path)
            Wallpapers.setWallpaper(path);
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle Caelestia launcher (wallpaper mode)"
        onPressed: toggleLauncherWallpaper()
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper"
        onPressed: pickRandomWallpaper()
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            toggleLauncherWallpaper();
        }

        function random(): void {
            pickRandomWallpaper();
        }
    }
}
