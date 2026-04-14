pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import qs.modules.controlcenter
import QtQuick
import QtQuick.Layouts

// Chrome metrics from ControlCenterChrome (qs.services.shell); header fill matches main canvas.
Item {
    id: root

    required property Session session
    property bool floating: false
    required property int sidebarWidth
    property int topRadius: 0

    readonly property var paneInfo: PaneRegistry.getByLabel(root.session.active)
    readonly property int barHeight: ControlCenterChrome.headerBarHeight

    Layout.fillWidth: true
    Layout.preferredHeight: root.barHeight
    Layout.maximumHeight: root.barHeight
    Layout.minimumHeight: root.barHeight
    implicitHeight: root.barHeight
    clip: true

    Rectangle {
        z: -1
        anchors.fill: parent
        color: ControlCenterChrome.canvasColor
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        height: root.barHeight

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.preferredWidth: root.sidebarWidth
                Layout.fillHeight: true

                StyledText {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Settings")
                    font.pointSize: Appearance.font.size.larger
                    font.weight: Font.Bold
                    color: Colours.palette.m3onSurface
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.paneInfo ? root.paneInfo.title : root.session.active
                    font.pointSize: Appearance.font.size.larger
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurface
                }
            }

            Item {
                Layout.preferredWidth: root.floating ? 40 : 0
                Layout.preferredHeight: root.barHeight
                visible: root.floating

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    fill: 0
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.m3onSurfaceVariant
                }

                StateLayer {
                    anchors.fill: parent
                    radius: width / 2
                    color: Colours.palette.m3onSurface

                    function onClicked(): void {
                        root.session.root.close();
                    }
                }
            }

            Item {
                Layout.preferredWidth: root.floating ? Appearance.padding.normal : 0
            }
        }
    }
}

