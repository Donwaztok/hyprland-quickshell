import qs.services.shell
import QtQuick
import qs.modules.shell.onScreenDisplay

KeyboardLockIndicator {
    active: Hypr.capsLock
    icon: Hypr.capsLock ? "keyboard_capslock_badge" : "keyboard_capslock"
    name: qsTr("Caps Lock")
}
