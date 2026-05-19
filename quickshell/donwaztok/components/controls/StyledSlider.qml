import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Templates

// GtkScale / Adwaita-style: thin track + circular handle (not a tall vertical bar).
Slider {
    id: root

    implicitHeight: 32
    leftPadding: 10
    rightPadding: 10
    property real trackHeight: 4
    property real handleSize: 20

    background: Item {
        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding

        StyledRect {
            id: trackGroove

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.trackHeight
            radius: root.trackHeight / 2
            color: Qt.rgba(
                Colours.palette.m3onSurface.r,
                Colours.palette.m3onSurface.g,
                Colours.palette.m3onSurface.b,
                0.28
            )
        }

        StyledRect {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: root.trackHeight
            width: Math.max(0, root.visualPosition * (trackGroove.width - root.handleSize) + root.handleSize / 2)
            radius: root.trackHeight / 2
            color: Colours.palette.m3primary
        }
    }

    handle: Item {
        width: root.handleSize
        height: root.handleSize

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
