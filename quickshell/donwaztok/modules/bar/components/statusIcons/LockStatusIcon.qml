import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// Caps and num lock. The status area collapses while neither is on; the tray keeps its square slot and
// shows a dimmed caps lock glyph instead.
ColumnLayout {
    id: root

    property color colour
    property bool inTray

    spacing: 0

    MaterialIcon {
        visible: root.inTray
        Layout.alignment: Qt.AlignHCenter
        pointSizeScale: Config.barThicknessScale
        text: !Hypr.capsLock && Hypr.numLock ? "looks_one" : "keyboard_capslock_badge"
        color: root.colour
        opacity: Hypr.capsLock || Hypr.numLock ? 1 : 0.4
    }

    Item {
        visible: !root.inTray
        implicitWidth: capslockIcon.implicitWidth
        implicitHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0

        MaterialIcon {
            id: capslockIcon

            anchors.centerIn: parent
            pointSizeScale: Config.barThicknessScale

            scale: Hypr.capsLock ? 1 : 0.5
            opacity: Hypr.capsLock ? 1 : 0

            text: "keyboard_capslock_badge"
            color: root.colour

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }

    Item {
        visible: !root.inTray
        Layout.topMargin: Hypr.capsLock && Hypr.numLock ? Math.max(1, Math.round(Appearance.spacing.small * Config.barThicknessScale)) : 0

        implicitWidth: numlockIcon.implicitWidth
        implicitHeight: Hypr.numLock ? numlockIcon.implicitHeight : 0

        MaterialIcon {
            id: numlockIcon

            anchors.centerIn: parent
            pointSizeScale: Config.barThicknessScale

            scale: Hypr.numLock ? 1 : 0.5
            opacity: Hypr.numLock ? 1 : 0

            text: "looks_one"
            color: root.colour

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }
}
