pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property real sizeFactor: (Config.bar.size ?? 1)
    readonly property int effectiveInnerWidth: Math.round(Config.bar.sizes.innerWidth * sizeFactor)
    readonly property int padSm: Math.max(1, Math.round(Appearance.padding.small * sizeFactor))
    readonly property int padN: Math.max(1, Math.round(Appearance.padding.normal * sizeFactor))
    readonly property int spaceSm: Math.max(1, Math.round(Appearance.spacing.small * sizeFactor))
    readonly property alias layout: layoutDims
    readonly property alias items: items

    Item {
        id: layoutDims
        implicitWidth: barVertical ? (root.effectiveInnerWidth - root.padding * 2) : layoutRow.implicitWidth
        implicitHeight: barVertical ? root.verticalContentHeight : layoutRow.implicitHeight
    }
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? root.padN : root.padSm
    readonly property int spacing: Config.bar.tray.background ? root.spaceSm : 0
    readonly property int trayItemSize: Appearance.font.size.small * 2

    property bool expanded

    readonly property real verticalContentHeight: items.count * root.trayItemSize + Math.max(0, items.count - 1) * root.spaceSm
    readonly property real nonAnimHeight: {
        if (root.barVertical) {
            if (!Config.bar.tray.compact)
                return root.verticalContentHeight + padding * 2;
            return (expanded ? expandIcon.implicitHeight + root.verticalContentHeight + spacing : expandIcon.implicitHeight) + padding * 2;
        }
        return root.effectiveInnerWidth;
    }
    readonly property real nonAnimWidth: {
        if (!root.barVertical) {
            if (!Config.bar.tray.compact)
                return layoutRow.implicitWidth + padding * 2;
            return (expanded ? expandIcon.implicitWidth + layoutRow.implicitWidth + spacing : expandIcon.implicitWidth) + padding * 2;
        }
        return root.effectiveInnerWidth;
    }

    clip: true
    visible: height > 0

    implicitWidth: barVertical ? root.effectiveInnerWidth : nonAnimWidth
    implicitHeight: barVertical ? nonAnimHeight : root.effectiveInnerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    ColumnLayout {
        id: layoutColumn

        visible: barVertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.padding
        width: root.barVertical ? (root.effectiveInnerWidth - root.padding * 2) : undefined
        spacing: root.spaceSm

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => !Config.bar.tray.hiddenIcons.includes(i.id))
            }

            delegate: Item {
                required property var modelData
                Layout.preferredHeight: root.trayItemSize
                Layout.preferredWidth: root.effectiveInnerWidth - root.padding * 2
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: root.effectiveInnerWidth - root.padding * 2
                implicitHeight: root.trayItemSize

                TrayItem {
                    modelData: parent.modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Behavior on opacity { Anim {} }
    }

    Row {
        id: layoutRow

        visible: !barVertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: expandIcon.active ? expandIcon.left : undefined
        anchors.leftMargin: root.padding
        anchors.rightMargin: expandIcon.active ? root.spacing : root.padding
        spacing: root.spaceSm

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
            implicitHeight: expandIconInner.implicitHeight

            MaterialIcon {
                id: expandIconInner

                anchors.centerIn: parent
                text: root.barVertical ? "expand_less" : "expand_more"
                font.pointSize: Appearance.font.size.large
                rotation: root.expanded ? (root.barVertical ? 180 : 180) : 0

                Behavior on rotation { Anim {} }
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
