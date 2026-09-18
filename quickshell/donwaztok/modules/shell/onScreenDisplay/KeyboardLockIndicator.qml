import qs.modules.common
import qs.modules.common.widgets
import qs.services.shell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property bool active
    required property string icon
    required property string name

    readonly property int hPad: 16
    readonly property int vPad: 10

    implicitWidth: chip.implicitWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: chip.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: chip
    }

    Rectangle {
        id: chip

        anchors.centerIn: parent
        radius: Appearance.rounding.full
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        implicitWidth: row.implicitWidth + root.hPad * 2
        implicitHeight: row.implicitHeight + root.vPad * 2

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.icon
                iconSize: 22
                fill: root.active ? 1 : 0
                color: root.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.name
                color: Colours.palette.m3onSurface
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                radius: Appearance.rounding.full
                color: root.active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                implicitWidth: statusLabel.implicitWidth + 14
                implicitHeight: statusLabel.implicitHeight + 6

                StyledText {
                    id: statusLabel

                    anchors.centerIn: parent
                    text: root.active ? qsTr("On") : qsTr("Off")
                    color: root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                    }
                }
            }
        }
    }
}
