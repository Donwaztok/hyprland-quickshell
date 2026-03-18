pragma ComponentBehavior: Bound

import caelestia.services
import caelestia.config
import caelestia.components
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

StyledClippingRect {
    id: root

    required property ShellScreen screen

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"

    readonly property bool onSpecial: (Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject?.specialWorkspace?.name !== ""
    readonly property int activeWsId: Config.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    implicitWidth: barVertical ? Config.bar.sizes.innerWidth : (layout.implicitWidth + Appearance.padding.small * 2)
    implicitHeight: barVertical ? (layout.implicitHeight + Appearance.padding.small * 2) : Config.bar.sizes.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        GridLayout {
            id: layout

            anchors.centerIn: parent
            rowSpacing: Math.floor(Appearance.spacing.small / 2)
            columnSpacing: Math.floor(Appearance.spacing.small / 2)

            flow: root.barVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.barVertical ? -1 : 1
            columns: root.barVertical ? 1 : -1

            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                Workspace {
                    barVertical: root.barVertical
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                }
            }
        }

        Loader {
            id: activeIndicatorLoader

            anchors.horizontalCenter: root.barVertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: root.barVertical ? undefined : parent.verticalCenter
            active: Config.bar.workspaces.activeIndicator

            Binding on x {
                when: !root.barVertical && activeIndicatorLoader.item && workspaces.itemAt(activeIndicatorLoader.item.currentWsIdx)
                value: layout.mapToItem(activeIndicatorLoader.parent, workspaces.itemAt(activeIndicatorLoader.item.currentWsIdx).x, 0).x
            }
            Binding on x {
                when: root.barVertical
                value: 0
            }

            sourceComponent: ActiveIndicator {
                screen: root.screen
                barVertical: root.barVertical
                workspaces: workspaces
                mask: layout
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = layout.childAt(event.x, event.y).ws;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(`workspace ${ws}`);
                else
                    Hypr.dispatch("togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
}
