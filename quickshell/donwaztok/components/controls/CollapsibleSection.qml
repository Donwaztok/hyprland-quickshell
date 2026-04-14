import ".."
import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    default property alias content: contentColumn.data

    required property string title
    property string description: ""
    property bool expanded: false
    property bool collapsible: true
    property bool showBackground: false
    property bool nested: false
    // Adwaita-style boxed row (e.g. Appearance sidebar accordions)
    property bool gnomeListRow: false

    signal toggleRequested

    spacing: root.gnomeListRow ? Appearance.spacing.smaller : Appearance.spacing.small
    Layout.fillWidth: true

    Item {
        id: chromeHost
        Layout.fillWidth: true
        implicitHeight: innerColumn.implicitHeight

        StyledRect {
            visible: root.gnomeListRow
            z: -1
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: ControlCenterChrome.settingsGroupCard
            border.width: 1
            border.color: ControlCenterChrome.settingsGroupCardBorder

            Elevation {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                level: Colours.light ? 1 : 2
            }
        }

        ColumnLayout {
            id: innerColumn
            width: parent.width
            spacing: root.gnomeListRow ? 0 : Appearance.spacing.small

            Item {
                id: sectionHeaderItem
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(titleRow.implicitHeight + Appearance.padding.large * 2, 48)

                RowLayout {
                    id: titleRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: root.title
                        font.pointSize: Appearance.font.size.larger
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurface
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    MaterialIcon {
                        visible: root.collapsible
                        text: "expand_more"
                        rotation: root.expanded ? 180 : 0
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.normal
                        Behavior on rotation {
                            Anim {
                                duration: Appearance.anim.durations.small
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    color: Colours.palette.m3onSurface
                    radius: Appearance.rounding.normal
                    enabled: root.collapsible
                    showHoverBackground: root.collapsible
                    function onClicked(): void {
                        if (!root.collapsible)
                            return;
                        root.toggleRequested();
                        root.expanded = !root.expanded;
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.showBackground ? 0 : 1
                visible: !root.showBackground && (!root.gnomeListRow || root.expanded)
                color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.26)
            }

            Item {
                id: contentWrapper
                Layout.fillWidth: true
                Layout.preferredHeight: root.expanded ? (contentColumn.implicitHeight + (root.gnomeListRow ? Appearance.spacing.smaller : Appearance.spacing.small) * 2) : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                StyledRect {
                    id: backgroundRect
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, root.nested ? 3 : 2) : (root.nested ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer)
                    opacity: root.showBackground && root.expanded && !root.gnomeListRow ? 1.0 : 0.0
                    visible: root.showBackground && !root.gnomeListRow

                    Behavior on opacity {
                        Anim {
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                    }
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: root.gnomeListRow ? Appearance.spacing.smaller : Appearance.spacing.small
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.large
                    anchors.bottomMargin: root.gnomeListRow ? Appearance.spacing.smaller : Appearance.spacing.small
                    spacing: Appearance.spacing.small
                    opacity: root.expanded ? 1.0 : 0.0

                    Behavior on opacity {
                        Anim {
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                    }

                    StyledText {
                        id: descriptionText
                        Layout.fillWidth: true
                        Layout.topMargin: root.description !== "" ? Appearance.spacing.smaller : 0
                        Layout.bottomMargin: root.description !== "" ? Appearance.spacing.small : 0
                        visible: root.description !== ""
                        text: root.description
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (!root.collapsible)
            root.expanded = true;
    }

    onCollapsibleChanged: {
        if (!root.collapsible)
            root.expanded = true;
    }
}
