pragma ComponentBehavior: Bound

import caelestia.config
import caelestia.services
import Quickshell
import Quickshell.Wayland

// Idle timeouts from Config.general.idle (no caelestia lock module — use session locker).
Scope {
    id: root

    readonly property bool enabled: !Config.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            Quickshell.execDetached(["loginctl", "lock-session"]);
        else if (action === "unlock")
            Quickshell.execDetached(["loginctl", "unlock-session"]);
        else if (typeof action === "string")
            Hypr.dispatch(action);
        else
            Quickshell.execDetached(action);
    }

    LogindManager {
        onAboutToSleep: {
            if (Config.general.idle.lockBeforeSleep)
                Quickshell.execDetached(["loginctl", "lock-session"]);
        }
        onLockRequested: Quickshell.execDetached(["loginctl", "lock-session"])
        onUnlockRequested: Quickshell.execDetached(["loginctl", "unlock-session"])
    }

    Variants {
        model: Config.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
