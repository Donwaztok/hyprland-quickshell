import qs.components
import qs.config
import QtQuick

Loader {
    id: root

    property bool shown: true

    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: opacity > 0

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
}
