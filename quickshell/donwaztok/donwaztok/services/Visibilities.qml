pragma Singleton

import donwaztok.modules.controlcenter
import Quickshell

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    /// Bar popouts wrapper per Hyprland monitor (for detached / modal control center).
    property var popoutsByMonitor: new Map()
    /// Bumped when a bar registers so bindings (e.g. Visualiser) re-evaluate.
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
