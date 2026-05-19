pragma ComponentBehavior: Bound

import "items"
import qs.components
import qs.components.controls
import qs.config
import qs.services
import qs.modules.common.functions
import Quickshell
import QtQuick

Item {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    readonly property int columns: 8
    readonly property int cellSize: 44
    readonly property int maxRows: 6

    property alias count: grid.count
    property alias currentIndex: grid.currentIndex
    property alias currentItem: grid.currentItem

    implicitWidth: columns * cellSize
    implicitHeight: Math.min(
        maxRows * cellSize,
        Math.max(cellSize, Math.ceil(count / columns) * cellSize)
    )

    function refresh(): void {
        emojiModel.values = Emojis.fuzzyQuery(
            StringUtils.cleanOnePrefix(search.text, [Config.launcher.emojiPrefix]).trim()
        );
        grid.currentIndex = 0;
    }

    function moveSelection(rowDelta: int, colDelta: int): void {
        if (grid.count === 0)
            return;
        const col = grid.currentIndex % columns;
        const row = Math.floor(grid.currentIndex / columns);
        const maxRow = Math.floor((grid.count - 1) / columns);
        const newCol = Math.max(0, Math.min(columns - 1, col + colDelta));
        const newRow = Math.max(0, Math.min(maxRow, row + rowDelta));
        const newIndex = newRow * columns + newCol;
        if (newIndex < grid.count)
            grid.currentIndex = newIndex;
    }

    function incrementCurrentIndex(): void {
        moveSelection(1, 0);
    }

    function decrementCurrentIndex(): void {
        moveSelection(-1, 0);
    }

    function incrementCurrentIndexHorizontal(): void {
        if (grid.currentIndex + 1 < grid.count)
            grid.currentIndex += 1;
        else
            grid.currentIndex = 0;
    }

    function decrementCurrentIndexHorizontal(): void {
        if (grid.currentIndex > 0)
            grid.currentIndex -= 1;
        else
            grid.currentIndex = Math.max(0, grid.count - 1);
    }

    ScriptModel {
        id: emojiModel
    }

    GridView {
        id: grid

        anchors.fill: parent
        model: emojiModel
        clip: true

        cellWidth: root.cellSize
        cellHeight: root.cellSize

        keyNavigationEnabled: false
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Appearance.anim.durations.small

        highlight: StyledRect {
            radius: Appearance.rounding.normal
            color: Colours.palette.m3primary
            opacity: 0.18
            border.width: 2
            border.color: Colours.palette.m3primary
        }

        delegate: EmojiGridCell {
            required property var modelData
            required property int index

            width: grid.cellWidth
            height: grid.cellHeight
            visibilities: root.visibilities
            entry: modelData
            selected: GridView.isCurrentItem
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: grid
    }

    Connections {
        target: search
        function onTextChanged(): void {
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
