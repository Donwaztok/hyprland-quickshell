pragma ComponentBehavior: Bound

import qs.services.shell
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    property alias lock: lock

    function activateLock(): void {
        Hypr.extras.refreshDevices();
        lock.locked = true;
    }

    WlSessionLock {
        id: lock

        signal unlock

        // While locked, global shortcuts can be flaky; keep Caps/Num/layout in sync.
        Timer {
            running: lock.locked
            interval: 300
            repeat: true
            onTriggered: Hypr.extras.refreshDevices()
        }

        LockSurface {
            id: lockSurface
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    // Hyprland: global donwaztok:lock | donwaztok:unlock | donwaztok:lockFocus (hypridle, keybinds, LauncherConfig).
    GlobalShortcut {
        appid: "donwaztok"
        name: "lock"
        description: "Lock the current session"
        onPressed: root.activateLock()
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "lockFocus"
        description: "Re-focus the lock screen password field (e.g. after resume)"
        onPressed: {
            if (lock.locked)
                lockSurface.refocusLockInput();
        }
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            root.activateLock();
        }

        function lock(): void {
            root.activateLock();
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        function focus(): void {
            if (lock.locked)
                lockSurface.refocusLockInput();
        }
    }
}
