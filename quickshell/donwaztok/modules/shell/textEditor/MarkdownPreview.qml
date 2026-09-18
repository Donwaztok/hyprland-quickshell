import qs.components
import qs.components.controls
import qs.services.shell
import qs.config as Theme
import Quickshell
import QtQuick
import QtQuick.Layouts

Flickable {
    id: root

    property var blocks: []

    readonly property var blockList: {
        const b = root.blocks;
        if (!b)
            return [];
        if (Array.isArray(b))
            return b;
        const n = b.length;
        if (typeof n !== "number" || n <= 0)
            return [];
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push(b[i]);
        return out;
    }

    clip: true
    implicitWidth: 0
    implicitHeight: 0
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    contentWidth: width
    contentHeight: Math.max(height, col.y + col.height)

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    Column {
        id: col
        x: Theme.Appearance.padding.large
        y: Theme.Appearance.padding.small
        width: Math.max(0, root.width - Theme.Appearance.padding.large * 2)
        spacing: Theme.Appearance.spacing.normal

        Repeater {
            model: ScriptModel {
                values: root.blockList
            }

            delegate: BlockItem {
                required property var modelData
                width: col.width
                block: modelData
            }
        }
    }

    component MdText: Text {
        width: parent ? parent.width : 0
        textFormat: Text.RichText
        wrapMode: Text.Wrap
        color: Colours.palette.m3onSurface
        linkColor: Colours.palette.m3primary
        renderType: Text.QtRendering
        font.family: Theme.Appearance.font.family.sans
        font.pointSize: Math.max(13, Theme.Appearance.font.size.normal)
        onLinkActivated: url => Qt.openUrlExternally(url)
        HoverHandler {
            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    component CodeChip: StyledRect {
        property string label: ""
        property int pointSize: Theme.Appearance.font.size.small

        implicitHeight: Math.max(22, chipLabel.implicitHeight + 6)
        implicitWidth: chipLabel.implicitWidth + Theme.Appearance.padding.normal * 2
        radius: Theme.Appearance.rounding.full
        color: Colours.tPalette.m3surfaceContainerHighest
        border.width: 1
        border.color: ControlCenterChrome.settingsGroupCardBorder

        StyledText {
            id: chipLabel
            anchors.centerIn: parent
            text: parent.label
            color: Colours.palette.m3onSurfaceVariant
            font.family: Theme.Appearance.font.family.mono
            font.pointSize: parent.pointSize
            font.weight: Font.Medium
        }
    }

    component MdFlow: Flow {
        id: mdFlow
        property var parts: []
        property color textColor: Colours.palette.m3onSurfaceVariant
        property int pointSize: Math.max(13, Theme.Appearance.font.size.normal)
        property int weight: Font.Normal
        property bool italic: false
        width: parent ? parent.width : 0
        spacing: 6

        Repeater {
            model: ScriptModel {
                values: mdFlow.parts && mdFlow.parts.length ? mdFlow.parts : []
            }

            delegate: Item {
                id: partWrap
                required property var modelData
                readonly property bool isCode: !!(modelData && modelData.type === "code")
                width: isCode ? chip.implicitWidth : txt.width
                height: isCode ? chip.implicitHeight : txt.height

                MdText {
                    id: txt
                    visible: !partWrap.isCode
                    width: visible ? Math.min(implicitWidth, mdFlow.width) : 0
                    text: visible ? (modelData && modelData.html ? modelData.html : "") : ""
                    color: mdFlow.textColor
                    font.pointSize: mdFlow.pointSize
                    font.weight: mdFlow.weight
                    font.italic: mdFlow.italic
                }

                CodeChip {
                    id: chip
                    visible: partWrap.isCode
                    label: String(modelData && modelData.text ? modelData.text : "")
                    pointSize: Math.max(11, mdFlow.pointSize - 1)
                }
            }
        }
    }

    component BlockItem: Column {
        id: blk
        property var block: ({})
        spacing: 0

        readonly property string kind: blk.block && blk.block.type ? String(blk.block.type) : "p"
        readonly property var parts: blk.block && blk.block.parts ? blk.block.parts : []
        readonly property int headingLevel: Number(blk.block && blk.block.level ? blk.block.level : 1)

        MdFlow {
            visible: blk.kind === "h"
            height: visible ? implicitHeight : 0
            parts: visible ? blk.parts : []
            textColor: Colours.palette.m3onSurface
            pointSize: {
                const n = Math.max(13, Theme.Appearance.font.size.normal);
                if (blk.headingLevel <= 1)
                    return n + 10;
                if (blk.headingLevel === 2)
                    return n + 5;
                if (blk.headingLevel === 3)
                    return n + 2;
                return n;
            }
            weight: blk.headingLevel <= 2 ? Font.DemiBold : Font.Medium
        }

        Rectangle {
            visible: blk.kind === "h" && blk.headingLevel <= 2
            width: parent.width
            height: visible ? 1 : 0
            color: ControlCenterChrome.paneSectionRule
        }

        MdFlow {
            visible: blk.kind === "p"
            height: visible ? implicitHeight : 0
            parts: visible ? blk.parts : []
            textColor: Colours.palette.m3onSurfaceVariant
        }

        StyledRect {
            id: codeCard
            visible: blk.kind === "code"
            width: parent.width
            height: visible ? implicitHeight : 0
            implicitHeight: visible ? codeCol.implicitHeight + Theme.Appearance.padding.large * 2 : 0
            radius: Theme.Appearance.rounding.normal
            color: ControlCenterChrome.settingsGroupCard
            border.width: 1
            border.color: ControlCenterChrome.settingsGroupCardBorder

            property bool copied: false

            Timer {
                id: copyReset
                interval: 1400
                onTriggered: codeCard.copied = false
            }

            Column {
                id: codeCol
                visible: blk.kind === "code"
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.small

                Row {
                    width: parent.width
                    spacing: Theme.Appearance.spacing.small

                    StyledRect {
                        id: langChip
                        visible: !!(blk.block && blk.block.lang)
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 26
                        implicitWidth: langRow.implicitWidth + Theme.Appearance.padding.normal * 2
                        radius: Theme.Appearance.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHighest
                        border.width: 1
                        border.color: ControlCenterChrome.settingsGroupCardBorder

                        Row {
                            id: langRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "code"
                                fill: 0
                                font.pointSize: Theme.Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(blk.block && blk.block.lang ? blk.block.lang : "")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Theme.Appearance.font.size.small
                                font.family: Theme.Appearance.font.family.mono
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - (langChip.visible ? langChip.width + parent.spacing : 0) - copyBtn.width)
                        height: 1
                    }

                    StyledRect {
                        id: copyBtn
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Theme.Appearance.rounding.full
                        color: "transparent"

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                Quickshell.clipboardText = blk.block && blk.block.text ? String(blk.block.text) : "";
                                codeCard.copied = true;
                                copyReset.restart();
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: codeCard.copied ? "check" : "content_copy"
                            fill: 0
                            font.pointSize: Theme.Appearance.font.size.normal
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: blk.block && blk.block.text ? String(blk.block.text) : ""
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurface
                    font.family: Theme.Appearance.font.family.mono
                    font.pointSize: Math.max(12, Theme.Appearance.font.size.smaller)
                    renderType: Text.QtRendering
                }
            }
        }

        Row {
            visible: blk.kind === "quote"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Theme.Appearance.spacing.normal

            Rectangle {
                width: 3
                height: quoteBody.height
                radius: Theme.Appearance.rounding.full
                color: Colours.palette.m3primary
            }

            MdFlow {
                id: quoteBody
                width: parent.width - 3 - Theme.Appearance.spacing.normal
                parts: blk.parts
                textColor: Colours.palette.m3onSurfaceVariant
                italic: true
            }
        }

        Column {
            id: listCol
            visible: blk.kind === "list"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Theme.Appearance.spacing.small

            Repeater {
                model: ScriptModel {
                    values: blk.block && blk.block.items ? blk.block.items : []
                }

                delegate: Row {
                    required property int index
                    required property var modelData
                    width: listCol.width
                    spacing: Theme.Appearance.spacing.small

                    StyledText {
                        width: 22
                        text: {
                            const it = modelData;
                            if (it && it.task === true)
                                return "☑";
                            if (it && it.task === false)
                                return "☐";
                            if (blk.block && blk.block.ordered)
                                return `${index + 1}.`;
                            return "•";
                        }
                        font.pointSize: Theme.Appearance.font.size.small
                        color: Colours.palette.m3primary
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MdFlow {
                        width: parent.width - 22 - Theme.Appearance.spacing.small
                        parts: modelData && modelData.parts ? modelData.parts : []
                        textColor: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        StyledRect {
            id: tableCard
            visible: blk.kind === "table"
            width: parent.width
            height: visible ? implicitHeight : 0
            implicitHeight: visible ? tableCol.implicitHeight + Theme.Appearance.padding.normal * 2 : 0
            radius: Theme.Appearance.rounding.normal
            color: ControlCenterChrome.settingsGroupCard
            border.width: 1
            border.color: ControlCenterChrome.settingsGroupCardBorder
            clip: true

            readonly property var tableRows: {
                const d = blk.block || {};
                const heads = d.heads || [];
                const rows = d.rows || [];
                return heads.length ? [heads].concat(rows) : rows;
            }

            Column {
                id: tableCol
                x: 1
                y: 1
                width: parent.width - 2
                spacing: 0

                Repeater {
                    model: ScriptModel {
                        values: tableCard.tableRows
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: tableCol.width
                        implicitHeight: cellRow.implicitHeight + Theme.Appearance.padding.normal * 2
                        color: index === 0 ? Qt.alpha(Colours.palette.m3primary, 0.1) : index % 2 ? "transparent" : Qt.alpha(Colours.palette.m3outlineVariant, 0.1)

                        Row {
                            id: cellRow
                            x: Theme.Appearance.padding.normal
                            y: Theme.Appearance.padding.normal
                            width: parent.width - Theme.Appearance.padding.normal * 2
                            spacing: Theme.Appearance.spacing.small

                            Repeater {
                                model: ScriptModel {
                                    values: modelData
                                }

                                delegate: MdText {
                                    required property var modelData
                                    width: Math.max(72, cellRow.width / Math.max(1, (tableCard.tableRows[0] || []).length || 1))
                                    text: typeof modelData === "string" ? modelData : ""
                                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                    color: Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: blk.kind === "hr"
            width: parent.width
            height: visible ? 1 : 0
            color: ControlCenterChrome.paneSectionRule
        }
    }
}
