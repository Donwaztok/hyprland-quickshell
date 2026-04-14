pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import qs.modules.controlcenter
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    StyledFlickable {
        id: contentFlickable
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: contentLayout.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: contentFlickable
        }

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.normal

            Item {
                Layout.fillWidth: true
                implicitHeight: constrainedColumn.implicitHeight

                readonly property real maxContentWidth: 860

                ColumnLayout {
                    id: constrainedColumn
                    width: Math.min(parent.width, parent.maxContentWidth)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller / 2

                        StyledText {
                            text: qsTr("Hyprland look")
                            font.pointSize: Appearance.font.size.extraLarge
                            font.weight: Font.DemiBold
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Blur, shadows, and window opacity.")
                            wrapMode: Text.WordWrap
                            font.pointSize: Appearance.font.size.small
                            font.weight: Font.Medium
                            color: Colours.light ? Colours.palette.m3onSurfaceVariant : Qt.lighter(Colours.palette.m3onSurfaceVariant, 1.12)
                        }
                    }

                    StyledText {
                        visible: HyprlandSettings.fetchHint !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: HyprlandSettings.fetchHint
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Appearance.spacing.smaller
                        implicitHeight: 1
                        color: ControlCenterChrome.paneSectionRule
                    }

                    HyprlandTabDecoration {
                        Layout.fillWidth: true
                        ctl: HyprlandSettings
                    }
                }
            }
        }
    }
}
