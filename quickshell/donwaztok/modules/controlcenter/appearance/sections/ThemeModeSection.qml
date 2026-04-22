pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.modules.launcher.services
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

PreferencesGroup {
    id: root

    Layout.fillWidth: true
    title: qsTr("Style")
    description: qsTr("Light or dark look, and the accent color used across the shell.")

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        RowLayout {
            id: themeRow
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.normal

            /** Portrait-ish cards; capped width so they are not stretched edge-to-edge. */
            readonly property real cellW: Math.min(200, Math.max(132, (themeRow.width - themeRow.spacing) / 2))
            readonly property real cellH: Math.round(themeRow.cellW * 1.18)

            Repeater {
                model: [
                    { mode: "light", label: qsTr("Light") },
                    { mode: "dark", label: qsTr("Dark") }
                ]

                delegate: Item {
                    required property var modelData

                    Layout.preferredWidth: themeRow.cellW
                    Layout.preferredHeight: themeRow.cellH
                    Layout.maximumWidth: themeRow.cellW
                    implicitWidth: themeRow.cellW
                    implicitHeight: themeRow.cellH

                    readonly property bool isCurrent: (modelData.mode === "dark" && !Colours.currentLight) || (modelData.mode === "light" && Colours.currentLight)

                    StyledRect {
                        anchors.fill: parent
                        color: Colours.tPalette.m3surfaceContainer
                        radius: Appearance.rounding.normal
                        border.width: isCurrent ? 2 : 1
                        border.color: isCurrent ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)

                        StateLayer {
                            radius: parent.radius
                            function onClicked(): void {
                                Colours.setMode(modelData.mode);
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.smaller

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.small
                                color: modelData.mode === "dark" ? "#1f1f23" : "#f2f2f3"

                                StyledRect {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(parent.width * 0.42, 72)
                                    height: Math.min(parent.height * 0.48, 88)
                                    radius: Appearance.rounding.small
                                    color: modelData.mode === "dark" ? "#111114" : "#ffffff"
                                    border.width: 1
                                    border.color: Qt.alpha("#000000", modelData.mode === "dark" ? 0.30 : 0.08)
                                }

                                StyledRect {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.horizontalCenterOffset: -Math.min(parent.width * 0.12, 18)
                                    anchors.verticalCenterOffset: Math.min(parent.height * 0.08, 10)
                                    width: Math.min(parent.width * 0.38, 68)
                                    height: Math.min(parent.height * 0.44, 82)
                                    radius: Appearance.rounding.small
                                    color: modelData.mode === "dark" ? "#3e3e46" : "#dfdfe2"
                                    border.width: 1
                                    border.color: Qt.alpha("#000000", modelData.mode === "dark" ? 0.32 : 0.06)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                font.weight: isCurrent ? Font.DemiBold : Font.Medium
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                text: qsTr("Accent")
                color: Colours.palette.m3onSurface
                font.weight: Font.Medium
            }

            Flow {
                id: colorFlow
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                flow: Flow.LeftToRight

                Repeater {
                    /** Primary seed only (surfaces/secondaries stay default tonalspot). */
                    model: [
                        { seed: "ffd369" },
                        { seed: "c9a227" },
                        { seed: "ec5b2a" },
                        { seed: "6d8769" },
                        { seed: "5d9b17" },
                        { seed: "0aa36f" },
                        { seed: "2f9f9f" },
                        { seed: "1888ea" },
                        { seed: "7868d8" },
                        { seed: "9e9e9e" }
                    ]

                    delegate: StyledRect {
                        required property var modelData

                        width: 22
                        height: 22
                        radius: Appearance.rounding.full
                        border.width: modelData.seed === Colours.accentSeedHex ? 2 : 1
                        /** Role `m3primary` in light mode is darkened for buttons — never use it for the chip ring or it mismatches `#seed`. */
                        border.color: modelData.seed === Colours.accentSeedHex ? ("#" + modelData.seed) : Qt.alpha(Colours.palette.m3outlineVariant, 0.58)
                        color: "#" + modelData.seed

                        StateLayer {
                            radius: parent.radius
                            function onClicked(): void {
                                applyAccent(modelData.seed);
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: reloadTimer
            interval: 300
            onTriggered: {
                Schemes.reload();
            }
        }
    }

    function applyAccent(seed) {
        Colours.writePrimaryAccent(seed, "tonalspot");
        Qt.callLater(() => {
            reloadTimer.restart();
        });
    }
}
