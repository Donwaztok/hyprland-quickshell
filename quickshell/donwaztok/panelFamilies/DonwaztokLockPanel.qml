pragma ComponentBehavior: Bound

import qs
import qs.modules.lock
import Quickshell
import QtQuick

// Wraps Donwaztok session lock and keeps GlobalStates.screenLocked in sync
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
