import qs.components
import qs.services.shell
import qs.config
import QtQuick

// Keycap drawn as a border rect with a thicker bottom edge.
StyledRect {
    id: root

    property string key

    property real horizontalPadding: 6
    property real verticalPadding: 1
    property real borderWidth: 1
    property real extraBottomBorderWidth: 2
    property color borderColor: Colours.palette.m3outlineVariant
    property real borderRadius: 5
    property real pixelSize: 12
    property color keyColor: Colours.palette.m3surfaceContainerLow
    property color textColor: Colours.palette.m3onSurface

    implicitWidth: keyFace.implicitWidth + borderWidth * 2
    implicitHeight: keyFace.implicitHeight + borderWidth * 2 + extraBottomBorderWidth
    radius: borderRadius
    color: borderColor

    StyledRect {
        id: keyFace

        anchors.fill: parent
        anchors.topMargin: root.borderWidth
        anchors.leftMargin: root.borderWidth
        anchors.rightMargin: root.borderWidth
        anchors.bottomMargin: root.extraBottomBorderWidth + root.borderWidth
        implicitWidth: keyText.implicitWidth + root.horizontalPadding * 2
        implicitHeight: keyText.implicitHeight + root.verticalPadding * 2
        color: root.keyColor
        radius: root.borderRadius - root.borderWidth

        StyledText {
            id: keyText

            anchors.centerIn: parent
            font.family: Appearance.font.family.mono
            font.pointSize: root.pixelSize * 0.75 // px → pt at 96 dpi
            color: root.textColor
            text: root.key
        }
    }
}
