pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    property alias lock: lock

    WlSessionLock {
        id: lock

        signal unlock

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
        onPressed: lock.locked = true
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
            lock.locked = true;
        }

        function lock(): void {
            lock.locked = true;
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
