import qs.modules.common
import qs.modules.common.widgets
import qs.services.shell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 20

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: valueIndicator
    }
    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout {
            id: valueRow
            Layout.margins: 10
            anchors.fill: parent
            spacing: 10

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                MaterialSymbol {
                    anchors {
                        centerIn: parent
                        alignWhenCentered: !root.rotateIcon
                    }
                    color: Colours.palette.m3onSurface
                    renderType: Text.QtRendering

                    text: root.icon
                    iconSize: 20 + 10 * (root.scaleIcon ? value : 1)
                    rotation: 180 * (root.rotateIcon ? value : 0)

                    Behavior on iconSize {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout {
                    Layout.leftMargin: valueProgressBar.height / 2
                    Layout.rightMargin: valueProgressBar.height / 2

                    StyledText {
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.name
                    }

                    StyledText {
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: false
                        text: Math.round(root.value * 100)
                    }
                }

                StyledProgressBar {
                    id: valueProgressBar
                    Layout.fillWidth: true
                    value: root.value
                    highlightColor: Colours.palette.m3primary
                    trackColor: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.42 : 0.38)
                }
            }
        }
    }
}
