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
        // surface is a Component, so its instance is reached only through this signal
        signal refocusRequested

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

            Connections {
                target: lock

                function onRefocusRequested(): void {
                    lockSurface.refocusLockInput();
                }
            }
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    // Hyprland: global donwaztok:lock | donwaztok:lockFocus (hypridle, keybinds, LauncherConfig).
    // No unlock shortcut or IPC: unlocking always goes through PAM (Pam.qml).
    GlobalShortcut {
        appid: "donwaztok"
        name: "lock"
        description: "Lock the current session"
        onPressed: root.activateLock()
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "lockFocus"
        description: "Re-focus the lock screen password field (e.g. after resume)"
        onPressed: {
            if (lock.locked)
                lock.refocusRequested();
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

        function isLocked(): bool {
            return lock.locked;
        }

        function focus(): void {
            if (lock.locked)
                lock.refocusRequested();
        }
    }
}
