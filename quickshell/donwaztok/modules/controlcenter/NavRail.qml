pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import qs.modules.controlcenter
import QtQuick
import QtQuick.Layouts

// GNOME Settings sidebar: neutral gray selection, outline icons, optional section rules.
Item {
    id: root

    required property Session session
    required property bool initialOpeningComplete

    readonly property int sidebarWidth: 252
    readonly property int rowHeight: 40
    readonly property int rowRadius: 8

    implicitWidth: sidebarWidth
    implicitHeight: flick.implicitHeight

    ColumnLayout {
        id: flick

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.large
        spacing: 0

        Repeater {
            model: PaneRegistry.count

            ColumnLayout {
                required property int index

                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: index === 3 ? Appearance.spacing.normal : 0
                    implicitHeight: index === 3 ? 1 : 0
                    visible: index === 3
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: index === 7 ? Appearance.spacing.normal : 0
                    implicitHeight: index === 7 ? 1 : 0
                    visible: index === 7
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                }

                SidebarRow {
                    Layout.fillWidth: true
                    Layout.topMargin: (index === 3 || index === 7) ? Appearance.spacing.small : (index > 0 ? Appearance.spacing.smaller : 0)

                    iconName: PaneRegistry.getByIndex(index).icon
                    labelText: PaneRegistry.getByIndex(index).title
                    selected: root.session.active === PaneRegistry.getByIndex(index).label
                    rowHeight: root.rowHeight
                    rowRadius: root.rowRadius

                    onTriggered: {
                        if (!root.initialOpeningComplete) {
                            return;
                        }
                        root.session.active = PaneRegistry.getByIndex(index).label;
                    }
                }
            }
        }
    }

    component SidebarRow: Item {
        id: rowRoot

        property string iconName: ""
        property string labelText: ""
        property bool selected: false
        property int rowHeight: 40
        property int rowRadius: 8

        signal triggered()

        implicitWidth: root.sidebarWidth - Appearance.padding.large * 2
        implicitHeight: rowHeight

        StyledRect {
            id: rowBg

            anchors.fill: parent
            radius: rowRoot.rowRadius
            color: rowRoot.selected
                ? Colours.tPalette.m3surfaceContainerHigh
                : "transparent"

            Rectangle {
                z: 2
                visible: rowRoot.selected
                width: 3
                radius: 2
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                color: Colours.palette.m3primary
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.padding.normal + (rowRoot.selected ? 5 : 0)
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: rowRoot.iconName
                    font.pointSize: Appearance.font.size.large
                    fill: 0
                    color: rowRoot.selected
                        ? Colours.palette.m3onSurface
                        : Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: rowRoot.labelText
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Normal
                    color: rowRoot.selected
                        ? Colours.palette.m3onSurface
                        : Colours.palette.m3onSurfaceVariant
                }
            }

            StateLayer {
                radius: rowRoot.rowRadius
                color: Colours.palette.m3onSurface

                function onClicked(): void {
                    rowRoot.triggered();
                }
            }
        }
    }
}
