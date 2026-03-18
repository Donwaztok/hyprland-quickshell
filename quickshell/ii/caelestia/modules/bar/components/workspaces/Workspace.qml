import caelestia.components
import caelestia.services
import caelestia.utils
import caelestia.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property bool barVertical
    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    readonly property bool isWorkspace: true
    readonly property int size: (root.barVertical ? implicitHeight : implicitWidth) + (hasWindows ? Appearance.padding.small : 0)

    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    readonly property string displayText: {
        const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
        const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
        let displayName = wsName.toString();
        if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
            displayName = displayName.toUpperCase();
        } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
            displayName = displayName.toLowerCase();
        }
        const label = Config.bar.workspaces.label || displayName;
        const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
        const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
        return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
    }

    readonly property color indicatorColor: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)

    implicitWidth: root.barVertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
    implicitHeight: root.barVertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

    Layout.alignment: Qt.AlignCenter
    Layout.preferredWidth: root.barVertical ? -1 : root.implicitWidth
    Layout.preferredHeight: root.barVertical ? root.implicitHeight : -1

    ColumnLayout {
        id: verticalLayout

        anchors.fill: parent
        visible: root.barVertical
        spacing: 0

        StyledText {
            id: indicatorVertical

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Config.bar.sizes.innerWidth - Appearance.padding.small * 2

            animate: true
            text: root.displayText
            color: root.indicatorColor
            verticalAlignment: Qt.AlignVCenter
        }

        Loader {
            id: windowsVertical

            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.topMargin: -Config.bar.sizes.innerWidth / 10

            visible: active
            active: root.hasWindows

            sourceComponent: Column {
                spacing: 0

                add: Transition {
                    Anim {
                        properties: "scale"
                        from: 0
                        to: 1
                        easing.bezierCurve: Appearance.anim.curves.standardDecel
                    }
                }
                move: Transition {
                    Anim { properties: "scale"; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
                    Anim { properties: "x,y" }
                }

                Repeater {
                    model: ScriptModel {
                        values: {
                            const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === root.ws);
                            const maxIcons = Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }
                    MaterialIcon {
                        required property var modelData
                        grade: 0
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }

    RowLayout {
        id: horizontalLayout

        anchors.fill: parent
        visible: !root.barVertical
        spacing: Math.floor(Appearance.spacing.small / 2)

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        StyledText {
            id: indicatorHorizontal

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2
            Layout.preferredHeight: Config.bar.sizes.innerWidth - Appearance.padding.small * 2

            animate: true
            text: root.displayText
            color: root.indicatorColor
            verticalAlignment: Qt.AlignVCenter
            horizontalAlignment: Qt.AlignHCenter
        }

        Loader {
            id: windowsHorizontal

            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 0
            visible: active
            active: root.hasWindows

            sourceComponent: Row {
                spacing: Math.floor(Appearance.spacing.small / 2)
                layoutDirection: Qt.LeftToRight

                property real iconSize: Math.max(1, (Config.bar.sizes.innerWidth - Appearance.padding.small * 2) * 0.65)

                add: Transition {
                    Anim {
                        properties: "scale"
                        from: 0
                        to: 1
                        easing.bezierCurve: Appearance.anim.curves.standardDecel
                    }
                }
                move: Transition {
                    Anim { properties: "scale"; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
                    Anim { properties: "x,y" }
                }

                Repeater {
                    model: ScriptModel {
                        values: {
                            const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === root.ws);
                            const maxIcons = Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }
                    Item {
                        required property var modelData
                        width: parent.iconSize
                        height: parent.iconSize
                        clip: true
                        MaterialIcon {
                            anchors.centerIn: parent
                            grade: 0
                            text: Icons.getAppCategoryIcon(parent.modelData.lastIpcObject.class, "terminal")
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }
    }

    Behavior on Layout.preferredHeight {
        Anim {}
    }
    Behavior on Layout.preferredWidth {
        Anim {}
    }
}
