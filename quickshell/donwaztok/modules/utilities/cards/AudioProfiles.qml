pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property bool showDisabled: false

    readonly property var visibleCards: {
        const cards = Audio.cards;
        if (!cards || !cards.length)
            return [];
        return cards.filter(c => c && (c.enabled || root.showDisabled));
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer

    function cardIcon(card: var): string {
        if (!card)
            return "developer_board";
        if (!card.enabled)
            return "power_off";
        if (card.hasSink && card.hasSource)
            return "headset_mic";
        if (card.hasSource)
            return "mic";
        const name = (card.description || "").toLowerCase();
        if (name.includes("hdmi") || name.includes("nvidia") || name.includes("gb205"))
            return "tv";
        if (name.includes("headphone") || name.includes("headset") || name.includes("stinger") || name.includes("cloud"))
            return "headphones";
        return "speaker";
    }

    function profileIcon(profile: var): string {
        if (!profile)
            return "tune";
        if (profile.name === "off")
            return "power_off";
        if (profile.name === "pro-audio")
            return "tune";
        if ((profile.sinks || 0) > 0 && (profile.sources || 0) > 0)
            return "headphones";
        if ((profile.sources || 0) > 0)
            return "mic";
        if ((profile.name || "").includes("hdmi"))
            return "tv";
        return "volume_up";
    }

    function visibleProfiles(card: var): var {
        return card?.profiles || [];
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "tune"
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Profiles")
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: root.closeRequested()
            }
        }

        StyledText {
            visible: root.visibleCards.length === 0
            Layout.fillWidth: true
            text: qsTr("No cards to show")
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            contentHeight: cardsColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: cardsColumn

                width: parent.width
                spacing: Appearance.spacing.normal

                Repeater {
                    model: root.visibleCards

                    ColumnLayout {
                        id: cardBlock

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller
                        opacity: modelData.enabled ? 1 : 0.55

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.smaller

                            MaterialIcon {
                                text: root.cardIcon(cardBlock.modelData)
                                color: cardBlock.modelData.enabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fill: cardBlock.modelData.enabled ? 1 : 0
                                font.pointSize: Appearance.font.size.normal
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: cardBlock.modelData.description || cardBlock.modelData.name
                                    font.weight: 500
                                    font.pointSize: Appearance.font.size.small
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: cardBlock.modelData.activeProfileLabel || cardBlock.modelData.activeProfile || qsTr("Unknown")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Math.round(Appearance.font.size.small * 0.85)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }

                        Repeater {
                            model: root.visibleProfiles(cardBlock.modelData)

                            Item {
                                id: profileOption

                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: optionRow.implicitHeight + Appearance.padding.small
                                opacity: modelData.available === false ? 0.4 : 1

                                StateLayer {
                                    disabled: modelData.available === false

                                    function onClicked(): void {
                                        Audio.setCardProfile(cardBlock.modelData.name, profileOption.modelData.name, true);
                                    }
                                }

                                RowLayout {
                                    id: optionRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Appearance.spacing.smaller

                                    MaterialIcon {
                                        text: profileOption.modelData.name === cardBlock.modelData.activeProfile ? "radio_button_checked" : "radio_button_unchecked"
                                        color: profileOption.modelData.name === cardBlock.modelData.activeProfile ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.normal
                                    }

                                    MaterialIcon {
                                        text: root.profileIcon(profileOption.modelData)
                                        color: profileOption.modelData.name === cardBlock.modelData.activeProfile ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.small
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: profileOption.modelData.label || profileOption.modelData.name
                                            font.pointSize: Appearance.font.size.smaller
                                            font.weight: profileOption.modelData.name === cardBlock.modelData.activeProfile ? 500 : 400
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            visible: (profileOption.modelData.sinks || 0) > 0 || (profileOption.modelData.sources || 0) > 0
                                            text: {
                                                const parts = [];
                                                if ((profileOption.modelData.sinks || 0) > 0)
                                                    parts.push(qsTr("%1 out").arg(profileOption.modelData.sinks));
                                                if ((profileOption.modelData.sources || 0) > 0)
                                                    parts.push(qsTr("%1 in").arg(profileOption.modelData.sources));
                                                return parts.join(" · ");
                                            }
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.pointSize: Math.round(Appearance.font.size.small * 0.85)
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    signal closeRequested
}
