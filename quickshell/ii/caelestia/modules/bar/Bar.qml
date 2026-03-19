pragma ComponentBehavior: Bound

import caelestia.services
import caelestia.config
import "popouts" as BarPopouts
import "components"
import "../../../modules/ii/bar" as IiBar
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts

    readonly property bool isVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property real sizeFactor: (Config.bar.size ?? 1)
    readonly property int vPadding: Math.max(2, Math.round(Appearance.padding.large * sizeFactor))
    readonly property int contentWidth: Math.round(Config.bar.sizes.innerWidth * sizeFactor) + Math.max(Math.round(Appearance.padding.smaller * sizeFactor), Config.border.thickness) * 2

    width: isVertical ? contentWidth : (parent?.width ?? 0)
    height: isVertical ? (parent?.height ?? 0) : contentWidth

    readonly property real spacing: Math.max(2, Math.round(Appearance.spacing.normal * sizeFactor))

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled && item.id === "tray") {
                item.item.expanded = false;
            }
        }
    }

    function isEntryEnabled(entryId: string): bool {
        const entries = Config.bar.entries ?? [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (entry?.id === entryId && entry.enabled !== false)
                return true;
        }
        return false;
    }

    function checkPopout(coord: real): void {
        const ch = (isVertical
            ? contentLayout.childAt(contentLayout.width / 2, coord)
            : contentLayout.childAt(coord, contentLayout.height / 2)) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const item = ch.item;
        const along = isVertical ? ch.y : ch.x;
        const itemSize = isVertical ? item.implicitHeight : item.implicitWidth;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = item.items;
            const mapped = mapToItem(items, isVertical ? width / 2 : coord, isVertical ? coord : height / 2);
            const icon = items.childAt(isVertical ? items.width / 2 : mapped.x, isVertical ? mapped.y : items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => isVertical ? icon.mapToItem(root, 0, icon.implicitHeight / 2).y : icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            if (!Config.bar.tray.compact || (item.expanded && !item.expandIcon.contains(mapToItem(item.expandIcon, item.implicitWidth / 2, isVertical ? coord : item.implicitHeight / 2)))) {
                const layoutSize = isVertical ? item.layout.implicitHeight : item.layout.implicitWidth;
                const index = Math.floor(((coord - along - item.padding * 2 + item.spacing) / layoutSize) * item.items.count);
                const trayItem = item.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => isVertical ? trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y : trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                item.expanded = true;
            }
        }
    }

    function handleWheel(coord: real, angleDelta: point): void {
        const halfScreen = isVertical ? screen.height / 2 : screen.width / 2;
        if (coord < halfScreen && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
        }
    }

    GridLayout {
        id: contentLayout

        anchors.fill: parent
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        rowSpacing: root.spacing
        columnSpacing: root.spacing

        Repeater {
            id: repeater

            model: Config.bar.entries

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "spacer"
                    delegate: WrappedLoader {
                        Layout.fillHeight: root.isVertical && enabled
                        Layout.fillWidth: !root.isVertical && enabled
                    }
                }
                DelegateChoice {
                    roleValue: "logo"
                    delegate: WrappedLoader {
                        sourceComponent: OsIcon {}
                    }
                }
                DelegateChoice {
                    roleValue: "workspaces"
                    delegate: WrappedLoader {
                        sourceComponent: IiBar.Workspaces {
                            vertical: root.isVertical
                            screenOverride: root.screen
                            overrideActiveColor: Colours.palette.m3primary
                            overrideInactiveColor: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "tray"
                    delegate: WrappedLoader {
                        sourceComponent: Tray {}
                    }
                }
                DelegateChoice {
                    roleValue: "clock"
                    delegate: WrappedLoader {
                        enabled: false
                    }
                }
                DelegateChoice {
                    roleValue: "statusIcons"
                    delegate: WrappedLoader {
                        sourceComponent: StatusIcons {}
                    }
                }
            }
        }
    }

    Loader {
        id: centeredClock

        anchors.centerIn: parent
        active: root.isEntryEnabled("clock")
        visible: active
        z: 10
        sourceComponent: Clock {}
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        function findLastEnabled(): Item {
            for (let i = repeater.count - 1; i >= 0; i--) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignVCenter

        Layout.topMargin: root.isVertical && findFirstEnabled() === this ? root.vPadding : 0
        Layout.bottomMargin: root.isVertical && findLastEnabled() === this ? root.vPadding : 0
        Layout.leftMargin: !root.isVertical && findFirstEnabled() === this ? root.vPadding : 0
        Layout.rightMargin: !root.isVertical && findLastEnabled() === this ? root.vPadding : 0

        visible: enabled
        active: enabled
    }
}
