pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property int effectiveInnerWidth: Config.bar.sizes.thickness
    readonly property int padSm: Math.max(1, Math.round(Appearance.padding.small * Config.barThicknessScale))
    readonly property int padN: Math.max(1, Math.round(Appearance.padding.normal * Config.barThicknessScale))
    readonly property int spaceSm: Math.max(1, Math.round(Appearance.spacing.small * Config.barThicknessScale))
    readonly property alias layout: layoutDims
    readonly property alias items: items
    // Bar.qml hit-tests the hovered slot in whichever layout is showing.
    readonly property Item activeLayout: barVertical ? layoutColumn : layoutRow

    Item {
        id: layoutDims
        implicitWidth: barVertical ? (root.effectiveInnerWidth - root.padding * 2) : layoutRow.implicitWidth
        implicitHeight: barVertical ? root.verticalContentHeight : layoutRow.implicitHeight
    }
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? root.padN : root.padSm
    readonly property int spacing: Config.bar.tray.background ? root.spaceSm : 0
    readonly property int trayItemSize: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))

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
        // Collapsed it sits under the chevron; opacity alone still takes clicks (touch has no hover to expand).
        enabled: root.expanded || !Config.bar.tray.compact

        Repeater {
            id: items

            model: ScriptModel {
                // Config.bar.icons.tray order: shell ids as strings, apps as their SystemTrayItem. Running apps
                // that are in no list yet go last; apps not running are skipped.
                values: {
                    const running = SystemTray.items.values;
                    const icons = Config.bar.icons;
                    const out = [];
                    for (const id of icons.tray) {
                        if (BarIcons.isApp(id)) {
                            const app = running.find(i => i.id === BarIcons.appId(id));
                            if (app)
                                out.push(app);
                        } else if (id in BarIcons.shell) {
                            out.push(id);
                        }
                    }
                    for (const app of running)
                        if (!icons.tray.includes(`app:${app.id}`) && !icons.hidden.includes(`app:${app.id}`))
                            out.push(app);
                    return out;
                }
            }

            delegate: Item {
                required property var modelData
                readonly property string popoutName: trayItem.popoutName
                Layout.preferredHeight: root.trayItemSize
                Layout.preferredWidth: root.effectiveInnerWidth - root.padding * 2
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: root.effectiveInnerWidth - root.padding * 2
                implicitHeight: root.trayItemSize

                TrayItem {
                    id: trayItem

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
        // Collapsed it sits under the chevron; opacity alone still takes clicks (touch has no hover to expand).
        enabled: root.expanded || !Config.bar.tray.compact

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
                font.pointSize: Appearance.font.size.large * Config.barThicknessScale
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
