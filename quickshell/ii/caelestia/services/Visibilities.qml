pragma Singleton

import Quickshell

Singleton {
    property var screens: new Map()
    property var bars: new Map()
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
}
