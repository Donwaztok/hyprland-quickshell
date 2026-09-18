import qs.services.shell
import QtQuick
import qs.modules.shell.onScreenDisplay

KeyboardLockIndicator {
    active: Hypr.numLock
    icon: Hypr.numLock ? "looks_one" : "timer_1"
    name: qsTr("Num Lock")
}
