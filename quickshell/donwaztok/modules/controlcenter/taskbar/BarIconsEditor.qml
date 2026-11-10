pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// Places bar icons in Status / Tray / Hidden (Config.bar.icons). Chips are dragged between and within
// groups; arrow keys and a menu do the same without a pointer.
Item {
    id: editor

    // The pane's Flickable, held still while a chip is dragged.
    property Flickable flickable
    // Chip to give focus back to once the lists are rebuilt after a move.
    property string focusId: ""
    property string draggingId: ""

    readonly property var groups: [
        {
            key: "status",
            label: qsTr("Status")
        },
        {
            key: "tray",
            label: qsTr("Tray")
        },
        {
            key: "hidden",
            label: qsTr("Hidden")
        }
    ]

    // What the bar shows: the config lists, with running apps that are in no list yet at the end of Tray.
    readonly property var current: {
        const icons = Config.bar.icons;
        const known = id => BarIcons.isApp(id) || id in BarIcons.shell;
        const out = {
            status: icons.status.filter(id => known(id) && !BarIcons.isApp(id)),
            tray: icons.tray.filter(known),
            hidden: icons.hidden.filter(known)
        };
        for (const app of SystemTray.items.values) {
            const id = `app:${app.id}`;
            if (!out.tray.includes(id) && !out.hidden.includes(id))
                out.tray.push(id);
        }
        return out;
    }

    function groupLabel(key: string): string {
        return groups.find(g => g.key === key)?.label ?? key;
    }

    function move(id: string, toGroup: string, toIndex: int): void {
        if (toGroup === "status" && BarIcons.isApp(id))
            return;
        const lists = {
            status: [...current.status],
            tray: [...current.tray],
            hidden: [...current.hidden]
        };
        for (const key in lists) {
            const at = lists[key].indexOf(id);
            if (at < 0)
                continue;
            lists[key].splice(at, 1);
            // The index was taken before removal; later slots shift left by one.
            if (key === toGroup && at < toIndex)
                toIndex--;
        }
        const target = lists[toGroup];
        target.splice(Math.max(0, Math.min(toIndex, target.length)), 0, id);
        editor.focusId = id;
        Config.bar.icons.status = lists.status;
        Config.bar.icons.tray = lists.tray;
        Config.bar.icons.hidden = lists.hidden;
        Config.save();
    }

    // Moves a chip one step: within its group (dx) or to the neighbouring group (dy), skipping Status for apps.
    function step(id: string, group: string, index: int, dx: int, dy: int): void {
        if (dx !== 0) {
            const to = index + dx;
            if (to >= 0 && to < current[group].length)
                move(id, group, dx > 0 ? to + 1 : to);
            return;
        }
        let g = groups.findIndex(x => x.key === group) + dy;
        if (g >= 0 && groups[g].key === "status" && BarIcons.isApp(id))
            g += dy;
        if (g >= 0 && g < groups.length)
            move(id, groups[g].key, index);
    }

    function startDrag(chip: Item): void {
        dragProxy.chipId = chip.chipId;
        dragProxy.isApp = chip.isApp;
        dragProxy.label = chip.label;
        dragProxy.glyph = chip.isApp ? "" : BarIcons.shell[chip.chipId].glyph;
        dragProxy.iconSource = chip.appIcon;
        editor.draggingId = chip.chipId;
        if (editor.flickable)
            editor.flickable.interactive = false;
    }

    function endDrag(): void {
        dragProxy.Drag.drop();
        editor.draggingId = "";
        if (editor.flickable)
            editor.flickable.interactive = true;
    }

    function openMenu(chip: Item): void {
        moveMenu.chipId = chip.chipId;
        moveMenu.group = chip.group;
        moveMenu.parent = chip;
        moveMenu.open();
    }

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.normal

        Repeater {
            model: editor.groups

            GroupArea {}
        }
    }

    // Follows the pointer while a chip is dragged; DropAreas read chipId/isApp from it.
    StyledRect {
        id: dragProxy

        property string chipId
        property bool isApp
        property string label
        property string glyph
        property string iconSource

        z: 100
        visible: editor.draggingId !== ""
        implicitWidth: proxyRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: proxyRow.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.full
        color: Colours.palette.m3secondaryContainer

        Drag.active: editor.draggingId !== ""
        Drag.keys: ["bar-icon"]
        Drag.source: dragProxy
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        RowLayout {
            id: proxyRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                visible: !dragProxy.isApp
                text: dragProxy.glyph
                color: Colours.palette.m3onSecondaryContainer
            }

            IconImage {
                visible: dragProxy.isApp
                implicitSize: Appearance.font.size.larger
                source: dragProxy.iconSource
            }

            StyledText {
                text: dragProxy.label
                color: Colours.palette.m3onSecondaryContainer
            }
        }
    }

    QQC2.Popup {
        id: moveMenu

        property string chipId
        property string group

        y: parent ? parent.height + Appearance.spacing.small : 0
        padding: Appearance.padding.small
        modal: false
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onOpened: menuRows.itemAt(0)?.forceActiveFocus()
        onClosed: {
            const chip = moveMenu.parent;
            if (chip && moveMenu.chipId === chip.chipId)
                chip.forceActiveFocus();
        }

        background: StyledRect {
            radius: Appearance.rounding.small
            color: Colours.palette.m3surfaceContainerHigh
        }

        contentItem: ColumnLayout {
            spacing: 0

            Repeater {
                id: menuRows

                model: editor.groups.filter(g => g.key !== moveMenu.group && !(g.key === "status" && BarIcons.isApp(moveMenu.chipId)))

                StyledRect {
                    id: menuRow

                    required property var modelData
                    required property int index

                    function choose(): void {
                        const id = moveMenu.chipId;
                        moveMenu.close();
                        editor.move(id, menuRow.modelData.key, editor.current[menuRow.modelData.key].length);
                    }

                    Layout.fillWidth: true
                    implicitWidth: menuText.implicitWidth + Appearance.padding.large * 2
                    implicitHeight: menuText.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: activeFocus ? Colours.palette.m3secondaryContainer : "transparent"

                    activeFocusOnTab: true
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: menuText.text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            const next = menuRows.itemAt(menuRow.index + (event.key === Qt.Key_Down ? 1 : -1));
                            next?.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            menuRow.choose();
                            event.accepted = true;
                        }
                    }

                    StateLayer {
                        radius: Appearance.rounding.small

                        function onClicked(): void {
                            menuRow.choose();
                        }
                    }

                    StyledText {
                        id: menuText

                        anchors.verticalCenter: parent.verticalCenter
                        x: Appearance.padding.large
                        text: qsTr("Move to %1").arg(menuRow.modelData.label)
                    }
                }
            }
        }
    }

    component GroupArea: ColumnLayout {
        id: area

        required property var modelData
        readonly property string key: modelData.key
        readonly property var ids: editor.current[key]
        property int dropIndex: -1

        // Chip delegates in flow order (the Flow also holds its Repeater).
        function chips(): var {
            const out = [];
            for (let i = 0; i < flow.children.length; i++)
                if (flow.children[i].chipId !== undefined)
                    out.push(flow.children[i]);
            return out;
        }

        // Insert position for a point in the box: before the first chip the point is ahead of, in reading order.
        function indexAt(x: real, y: real): int {
            const p = box.mapToItem(flow, x, y);
            const list = chips();
            for (let i = 0; i < list.length; i++) {
                const c = list[i];
                if (p.y < c.y || (p.y < c.y + c.height && p.x < c.x + c.width / 2))
                    return i;
            }
            return list.length;
        }

        Layout.fillWidth: true
        spacing: Appearance.spacing.smaller

        StyledText {
            text: area.modelData.label
            font.weight: Font.Medium
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledRect {
            id: box

            readonly property bool accepting: dropArea.containsDrag && area.dropIndex >= 0

            Layout.fillWidth: true
            implicitHeight: Math.max(flow.implicitHeight, emptyText.implicitHeight) + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: accepting ? Qt.alpha(Colours.palette.m3primary, 0.12) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
            border.width: 1
            border.color: accepting ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

            StyledText {
                id: emptyText

                anchors.centerIn: parent
                visible: area.ids.length === 0
                text: qsTr("Empty — drop icons here")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
            }

            Flow {
                id: flow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                Repeater {
                    model: area.ids

                    Chip {
                        group: area.key
                    }
                }
            }

            // Where the dragged chip will land.
            Rectangle {
                readonly property var list: box.accepting ? area.chips() : []
                readonly property Item ref: list[Math.min(area.dropIndex, list.length - 1)] ?? null
                readonly property bool after: area.dropIndex >= list.length

                visible: box.accepting && ref !== null
                width: 2
                height: ref?.height ?? 0
                radius: 1
                color: Colours.palette.m3primary
                x: flow.x + (ref ? (after ? ref.x + ref.width + flow.spacing / 2 : ref.x - flow.spacing / 2) : 0) - 1
                y: flow.y + (ref?.y ?? 0)
            }

            DropArea {
                id: dropArea

                anchors.fill: parent
                keys: ["bar-icon"]

                onEntered: drag => {
                    if (area.key === "status" && drag.source?.isApp) {
                        drag.accepted = false;
                        return;
                    }
                    area.dropIndex = area.indexAt(drag.x, drag.y);
                }
                onPositionChanged: drag => area.dropIndex = area.indexAt(drag.x, drag.y)
                onExited: area.dropIndex = -1
                onDropped: drop => {
                    const index = area.indexAt(drop.x, drop.y);
                    area.dropIndex = -1;
                    editor.move(drop.source.chipId, area.key, index);
                    drop.accept();
                }
            }
        }
    }

    component Chip: StyledRect {
        id: chip

        required property string modelData
        required property int index
        property string group

        readonly property string chipId: modelData
        readonly property bool isApp: BarIcons.isApp(chipId)
        readonly property var app: isApp ? (SystemTray.items.values.find(i => i.id === BarIcons.appId(chipId)) ?? null) : null
        readonly property string label: isApp ? (app?.title || BarIcons.appId(chipId)) : (BarIcons.shell[chipId]?.label ?? chipId)
        readonly property string appIcon: isApp ? Icons.getTrayIcon(BarIcons.appId(chipId), app?.icon ?? "") : ""

        implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2
        // Same height for glyph and app chips, so labels line up across a row.
        implicitHeight: glyph.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.full
        color: activeFocus ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest
        border.width: activeFocus ? 2 : 0
        border.color: Colours.palette.m3secondary
        opacity: editor.draggingId === chipId ? 0.4 : 1

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("%1, %2").arg(label).arg(editor.groupLabel(group))
        Accessible.description: qsTr("Arrow keys move it; Enter opens the move menu")

        Component.onCompleted: {
            if (editor.focusId === chipId) {
                editor.focusId = "";
                forceActiveFocus();
            }
        }

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Left || k === Qt.Key_Right)
                editor.step(chipId, group, index, k === Qt.Key_Right ? 1 : -1, 0);
            else if (k === Qt.Key_Up || k === Qt.Key_Down)
                editor.step(chipId, group, index, 0, k === Qt.Key_Down ? 1 : -1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Menu)
                editor.openMenu(chip);
            else
                return;
            event.accepted = true;
        }

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small
            opacity: chip.isApp && !chip.app ? 0.6 : 1

            MaterialIcon {
                id: glyph

                visible: !chip.isApp
                text: BarIcons.shell[chip.chipId]?.glyph ?? ""
                color: Colours.palette.m3onSurface
            }

            IconImage {
                visible: chip.isApp
                implicitSize: Math.round(glyph.implicitHeight * 0.8)
                source: chip.appIcon
            }

            StyledText {
                text: chip.label
                color: Colours.palette.m3onSurface
            }

            StyledText {
                visible: chip.isApp && !chip.app
                text: qsTr("Not running")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
            }
        }

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                chip.forceActiveFocus();
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: editor.openMenu(chip)
        }

        DragHandler {
            id: dragHandler

            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            onActiveChanged: active ? editor.startDrag(chip) : editor.endDrag()
            onCentroidChanged: {
                if (!active)
                    return;
                const p = editor.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                dragProxy.x = p.x - dragProxy.width / 2;
                dragProxy.y = p.y - dragProxy.height / 2;
            }
        }
    }
}
