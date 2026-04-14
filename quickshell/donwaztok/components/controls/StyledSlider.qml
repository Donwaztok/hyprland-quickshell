import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Templates

// GtkScale / Adwaita-style: thin track + circular handle (not a tall vertical bar).
Slider {
    id: root

    implicitHeight: 32

    background: Item {
        implicitHeight: 32

        readonly property real trackH: 4

        StyledRect {
            id: trackGroove

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: trackH
            radius: trackH / 2
            color: Colours.tPalette.m3surfaceContainerHighest
        }

        StyledRect {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: trackH
            width: Math.max(0, root.visualPosition * parent.width)
            radius: trackH / 2
            color: Colours.palette.m3primary
        }
    }

    handle: Item {
        width: 20
        height: 20

        x: root.visualPosition * (root.availableWidth - width)
        y: (root.implicitHeight - height) / 2

        StyledRect {
            anchors.fill: parent
            radius: width / 2
            color: Colours.palette.m3primary
            border.width: 2
            border.color: Colours.palette.m3surface
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
}
