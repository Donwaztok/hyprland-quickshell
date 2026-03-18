pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

StyledRect {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property alias layout: layoutDims
    readonly property alias items: items

    Item {
        id: layoutDims
        implicitWidth: barVertical ? layoutColumn.implicitWidth : layoutRow.implicitWidth
        implicitHeight: barVertical ? layoutColumn.implicitHeight : layoutRow.implicitHeight
    }
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? Appearance.padding.normal : Appearance.padding.small
    readonly property int spacing: Config.bar.tray.background ? Appearance.spacing.small : 0

    property bool expanded

    readonly property real nonAnimHeight: {
        if (root.barVertical) {
            if (!Config.bar.tray.compact)
                return layoutColumn.implicitHeight + padding * 2;
            return (expanded ? expandIcon.implicitHeight + layoutColumn.implicitHeight + spacing : expandIcon.implicitHeight) + padding * 2;
        }
        return Config.bar.sizes.innerWidth;
    }
    readonly property real nonAnimWidth: {
        if (!root.barVertical) {
            if (!Config.bar.tray.compact)
                return layoutRow.implicitWidth + padding * 2;
            return (expanded ? expandIcon.implicitWidth + layoutRow.implicitWidth + spacing : expandIcon.implicitWidth) + padding * 2;
        }
        return Config.bar.sizes.innerWidth;
    }

    clip: true
    visible: height > 0

    implicitWidth: barVertical ? Config.bar.sizes.innerWidth : nonAnimWidth
    implicitHeight: barVertical ? nonAnimHeight : Config.bar.sizes.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    Column {
        id: layoutColumn

        visible: barVertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.padding
        spacing: Appearance.spacing.small

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        add: Transition {
            Anim { properties: "scale"; from: 0; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
        }
        move: Transition {
            Anim { properties: "scale"; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
            Anim { properties: "x,y" }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => !Config.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }

        Behavior on opacity { Anim {} }
    }

    Row {
        id: layoutRow

        visible: !barVertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        spacing: Appearance.spacing.small

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        add: Transition {
            Anim { properties: "scale"; from: 0; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
        }
        move: Transition {
            Anim { properties: "scale"; to: 1; easing.bezierCurve: Appearance.anim.curves.standardDecel }
            Anim { properties: "x,y" }
        }

        Repeater {
            model: items.model

            TrayItem {}
        }

        Behavior on opacity { Anim {} }
    }

    Loader {
        id: expandIcon

        anchors.horizontalCenter: barVertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: barVertical ? undefined : parent.verticalCenter
        anchors.right: barVertical ? undefined : parent.right
        anchors.bottom: barVertical ? parent.bottom : undefined
        anchors.margins: root.padding

        active: Config.bar.tray.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth
            implicitHeight: expandIconInner.implicitHeight - Appearance.padding.small * 2

            MaterialIcon {
                id: expandIconInner

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Config.bar.tray.background ? Appearance.padding.small : -Appearance.padding.small
                text: root.barVertical ? "expand_less" : "expand_more"
                font.pointSize: Appearance.font.size.large
                rotation: root.expanded ? (root.barVertical ? 180 : 180) : 0

                Behavior on rotation { Anim {} }
                Behavior on anchors.bottomMargin { Anim {} }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
