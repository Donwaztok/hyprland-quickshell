pragma ComponentBehavior: Bound

import qs.services
import qs.services.shell
import qs.modules.common
import qs.modules.common.widgets as IIWidgets
import qs.components
import qs.components.effects
import qs.config as Theme
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real maxWidth: 1100
    readonly property real cardWidth: 340
    readonly property real keySpacing: 5
    readonly property var sections: HyprlandKeybinds.sections
    readonly property int columns: {
        const count = sections?.length ?? 0;
        if (count <= 0)
            return 1;
        const maxCols = Math.max(1, Math.floor((maxWidth + Theme.Appearance.spacing.large) / (cardWidth + Theme.Appearance.spacing.large)));
        return Math.min(3, maxCols, count);
    }

    implicitWidth: columns * cardWidth + Math.max(0, columns - 1) * Theme.Appearance.spacing.large
    implicitHeight: flow.implicitHeight

    property var macSymbolMap: ({
        "Ctrl": "󰘴",
        "Alt": "󰘵",
        "Shift": "󰘶",
        "Space": "󱁐",
        "Tab": "↹",
        "Equal": "󰇼",
        "Minus": "",
        "Print": "",
        "BackSpace": "󰭜",
        "Delete": "⌦",
        "Return": "󰌑",
        "Period": ".",
        "Escape": "⎋"
    })
    property var functionSymbolMap: ({
        "F1": "󱊫",
        "F2": "󱊬",
        "F3": "󱊭",
        "F4": "󱊮",
        "F5": "󱊯",
        "F6": "󱊰",
        "F7": "󱊱",
        "F8": "󱊲",
        "F9": "󱊳",
        "F10": "󱊴",
        "F11": "󱊵",
        "F12": "󱊶",
    })
    property var mouseSymbolMap: ({
        "mouse_up": "󱕐",
        "mouse_down": "󱕑",
        "mouse:272": "L󰍽",
        "mouse:273": "R󰍽",
        "Scroll ↑/↓": "󱕒",
        "Page_↑/↓": "⇞/⇟",
    })
    property var keyBlacklist: ["Super_L", "SUPER_L", "Super_R", "SUPER_R"]
    property var keySubstitutions: Object.assign({
        "Super": "",
        "mouse_up": "Scroll ↓",
        "mouse_down": "Scroll ↑",
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
    },
    !!Config.options.cheatsheet.superKey ? {
        "Super": Config.options.cheatsheet.superKey,
    } : {},
    Config.options.cheatsheet.useMacSymbol ? macSymbolMap : {},
    Config.options.cheatsheet.useFnSymbol ? functionSymbolMap : {},
    Config.options.cheatsheet.useMouseSymbol ? mouseSymbolMap : {},
    )

    component MouseKeycap: StyledRect {
        required property string mouseKey

        readonly property string sideLabel: {
            if (mouseKey === "mouse:272")
                return "L";
            if (mouseKey === "mouse:273")
                return "R";
            return "";
        }

        implicitWidth: content.implicitWidth + 12
        implicitHeight: content.implicitHeight + 8
        radius: 6
        color: Colours.palette.m3surfaceContainerHighest
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            StyledText {
                visible: sideLabel.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: sideLabel
                font.family: Theme.Appearance.font.family.mono
                font.pointSize: Theme.Appearance.font.size.small
                font.weight: Font.DemiBold
                color: Colours.palette.m3onSurface
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍽"
                font.family: Theme.Appearance.font.family.mono
                font.pointSize: Theme.Appearance.font.size.normal
                color: Colours.palette.m3onSurface
            }
        }
    }

    Flow {
        id: flow
        width: root.implicitWidth
        spacing: Theme.Appearance.spacing.large

        Repeater {
            model: root.sections

            delegate: StyledRect {
                id: categoryCard
                required property var modelData

                property int maxBindWidth: 0
                readonly property var binds: modelData.keybinds ?? []

                implicitWidth: root.cardWidth
                implicitHeight: cardColumn.implicitHeight + Theme.Appearance.padding.large * 2
                radius: Theme.Appearance.rounding.normal
                color: ControlCenterChrome.settingsGroupCard
                border.width: 1
                border.color: ControlCenterChrome.settingsGroupCardBorder

                Elevation {
                    z: -1
                    anchors.fill: parent
                    radius: parent.radius
                    level: Colours.light ? 1 : 2
                }

                ColumnLayout {
                    id: cardColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.Appearance.padding.large
                    spacing: Theme.Appearance.spacing.smaller

                    StyledText {
                        text: categoryCard.modelData.name
                        font.pointSize: Theme.Appearance.font.size.larger
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurface
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.Appearance.spacing.small

                        Repeater {
                            model: categoryCard.binds

                            delegate: RowLayout {
                                id: bindRow
                                required property var modelData
                                readonly property bool isMouse: (modelData.key || "").indexOf("mouse:") === 0

                                Layout.fillWidth: true
                                spacing: Theme.Appearance.spacing.normal

                                Item {
                                    id: keysBox
                                    Layout.preferredWidth: Math.max(categoryCard.maxBindWidth, implicitWidth)
                                    implicitWidth: keysRow.implicitWidth
                                    implicitHeight: keysRow.implicitHeight

                                    Component.onCompleted: {
                                        categoryCard.maxBindWidth = Math.max(categoryCard.maxBindWidth, implicitWidth);
                                    }

                                    Row {
                                        id: keysRow
                                        spacing: root.keySpacing

                                        Repeater {
                                            model: {
                                                const mods = [];
                                                const rawMods = bindRow.modelData.mods ?? [];
                                                for (let i = 0; i < rawMods.length; i++)
                                                    mods.push(root.keySubstitutions[rawMods[i]] || rawMods[i]);
                                                return mods;
                                            }

                                            delegate: IIWidgets.KeyboardKey {
                                                required property var modelData
                                                readonly property bool accent: {
                                                    const superLabel = root.keySubstitutions["Super"] || "Super";
                                                    return modelData === superLabel || modelData === "Super";
                                                }
                                                key: modelData
                                                pixelSize: Config.options.cheatsheet.fontSize.key
                                                horizontalPadding: 8
                                                verticalPadding: 3
                                                borderRadius: 6
                                                borderColor: accent ? Qt.alpha(Colours.palette.m3primary, 0.5) : Qt.alpha(Colours.palette.m3outlineVariant, 0.7)
                                                keyColor: accent ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
                                                textColor: accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                            }
                                        }

                                        StyledText {
                                            visible: (bindRow.modelData.mods?.length ?? 0) > 0 && !root.keyBlacklist.includes(bindRow.modelData.key)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "+"
                                            font.pointSize: Theme.Appearance.font.size.small
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        IIWidgets.KeyboardKey {
                                            visible: !root.keyBlacklist.includes(bindRow.modelData.key) && !bindRow.isMouse
                                            key: root.keySubstitutions[bindRow.modelData.key] || bindRow.modelData.key
                                            pixelSize: Config.options.cheatsheet.fontSize.key
                                            horizontalPadding: 8
                                            verticalPadding: 3
                                            borderRadius: 6
                                            borderColor: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)
                                            keyColor: Colours.palette.m3surfaceContainerHighest
                                            textColor: Colours.palette.m3onSurface
                                        }

                                        MouseKeycap {
                                            visible: bindRow.isMouse
                                            mouseKey: bindRow.modelData.key
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: bindRow.modelData.comment
                                    font.pointSize: Theme.Appearance.font.size.small
                                    font.weight: Font.Medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
