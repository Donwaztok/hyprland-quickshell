pragma ComponentBehavior: Bound

import qs
import caelestia.modules.lock
import Quickshell
import QtQuick

// Wraps Caelestia session lock and keeps ii GlobalStates.screenLocked in sync
// (on-screen keyboard, notification popup, background widgets).
Scope {
    Lock {
        id: caLock
    }

    Connections {
        target: caLock.lock

        function onLockedChanged() {
            GlobalStates.screenLocked = caLock.lock.locked
        }
    }
}
