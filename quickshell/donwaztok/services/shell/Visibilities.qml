pragma Singleton

import qs.config
import qs.modules.controlcenter
import Quickshell
import Quickshell.Hyprland

Singleton {
    property var screens: new Map()
    /// Bumped to apply Config.launcher.pendingOpenPrefix while launcher is already open on the focused monitor.
    property int launcherPrefixNonce: 0
    property var bars: new Map()
    /// Bar popouts wrapper per Hyprland monitor (for detached / modal control center).
    property var popoutsByMonitor: new Map()
    /// Bumped when a bar registers so bindings re-evaluate.
    property int barsRevision: 0

    function registerBar(screenName: string, barWrapper: var): void {
        bars.set(screenName, barWrapper);
        barsRevision++;
    }

    function load(screen: ShellScreen, visibilities: var): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function getForActive(): PersistentProperties {
        return screens.get(Hypr.focusedMonitor);
    }

    function closeLauncherExcept(keepMonitor: var): void {
        for (const [monitor, vis] of screens.entries()) {
            if (monitor !== keepMonitor)
                vis.launcher = false;
        }
    }

    function applyLauncherPrefix(prefix) {
        Config.launcher.pendingOpenPrefix = prefix;
        launcherPrefixNonce++;
    }

    /// Opens launcher on the focused monitor and closes it on all others.
    function openLauncher(prefix) {
        if (prefix === undefined)
            prefix = "";
        const monitor = Hypr.focusedMonitor;
        closeLauncherExcept(monitor);
        const v = getForActive();
        if (!v)
            return;
        if (prefix.length > 0) {
            if (v.launcher)
                applyLauncherPrefix(prefix);
            else
                Config.launcher.pendingOpenPrefix = prefix;
        } else {
            Config.launcher.pendingOpenPrefix = "";
        }
        v.launcher = true;
    }

    function toggleLauncher(): void {
        const v = getForActive();
        if (!v)
            return;
        if (v.launcher) {
            v.launcher = false;
            return;
        }
        openLauncher("");
    }

    function registerPopouts(monitor: var, popoutsWrapper: var): void {
        if (monitor)
            popoutsByMonitor.set(monitor, popoutsWrapper);
    }

    function getPopoutsForFocused(): var {
        return popoutsByMonitor.get(Hypr.focusedMonitor) ?? null;
    }

    /// Opens control center as a bar-layer modal when possible, else floating window.
    function openControlCenter(pane: string): void {
        const initial = pane && pane.length > 0 ? pane : "network";
        const p = popoutsByMonitor.get(Hypr.focusedMonitor);
        if (p) {
            p.detach(initial);
        } else {
            WindowFactory.create(null, initial === "network" ? {} : {
                active: initial
            });
        }
    }
}
