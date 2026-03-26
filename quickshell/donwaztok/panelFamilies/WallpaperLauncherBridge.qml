import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import qs.config as DwCfg
import qs.services.m3

/**
 * Hyprland globals quickshell:wallpaperSelectorToggle / wallpaperSelectorRandom and IPC
 * wallpaperSelector drive the Donwaztok launcher / random wallpaper flow.
 */
Scope {
    function toggleLauncherWallpaper(): void {
        if (!DwCfg.Config.loaded)
            return;
        const v = Visibilities.getForActive();
        if (!v)
            return;
        if (v.launcher) {
            v.launcher = false;
            return;
        }
        DwCfg.Config.launcher.pendingOpenPrefix = `${DwCfg.Config.launcher.actionPrefix}wallpaper`;
        v.launcher = true;
    }

    function pickRandomWallpaper(): void {
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
        description: "Toggle Donwaztok launcher (wallpaper mode)"
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
