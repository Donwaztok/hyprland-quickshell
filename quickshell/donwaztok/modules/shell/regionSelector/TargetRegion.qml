pragma ComponentBehavior: Bound
import qs.components
import qs.services
import qs.services.shell as Shell
import qs.config
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root
    required property var clientDimensions

    property color colBackground: Qt.alpha(Shell.Colours.palette.m3surfaceContainer, 0.85)
    property color colForeground: Shell.Colours.palette.m3onSurface
    property bool showLabel: Config.shellOptions?.regionSelector?.targetRegions?.showLabel ?? false
    property bool showIcon: false
    property bool targeted: false
    property color borderColor
    property color fillColor: "transparent"
    property string text: ""
    property real textPadding: 10
    property int borderWidth: targeted ? 4 : 2
    z: 2
    color: fillColor
    border.color: borderColor
    border.width: root.borderWidth
    radius: 4

    Behavior on color {
        CAnim {
            duration: Appearance.anim.durations.small
        }
    }

    visible: opacity > 0
    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
    x: clientDimensions.at[0]
    y: clientDimensions.at[1]
    width: clientDimensions.size[0]
    height: clientDimensions.size[1]

    Loader {
        anchors {
            top: parent.top
            left: parent.left
            topMargin: root.textPadding
            leftMargin: root.textPadding
        }
        
        active: root.showLabel
        sourceComponent: Rectangle {
            property real verticalPadding: 5
            property real horizontalPadding: 10
            radius: Appearance.rounding.small
            color: root.colBackground
            border.width: 1
            border.color: Shell.Colours.palette.m3outlineVariant
            implicitWidth: regionInfoRow.implicitWidth + horizontalPadding * 2
            implicitHeight: regionInfoRow.implicitHeight + verticalPadding * 2

            Row {
                id: regionInfoRow
                anchors.centerIn: parent
                spacing: 4

                Loader {
                    id: regionIconLoader
                    active: root.showIcon
                    visible: active
                    sourceComponent: IconImage {
                        implicitSize: 19
                        source: Quickshell.iconPath(AppSearch.guessIcon(root.text), "image-missing")
                    }
                }

                StyledText {
                    id: regionText
                    text: root.text
                    color: root.colForeground
                }
            }
        }
    }
}