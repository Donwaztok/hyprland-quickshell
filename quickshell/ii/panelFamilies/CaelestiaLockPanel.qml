pragma ComponentBehavior: Bound

import qs
import caelestia.modules.lock
import Quickshell
import QtQuick

// Wraps Caelestia session lock and keeps ii GlobalStates.screenLocked in sync
// (notification popup, background widgets, etc.).
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
