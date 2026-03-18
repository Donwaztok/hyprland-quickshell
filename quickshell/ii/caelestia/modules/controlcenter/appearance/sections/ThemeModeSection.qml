pragma ComponentBehavior: Bound

import ".."
import caelestia.components
import caelestia.components.controls
import caelestia.components.containers
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    title: qsTr("Colors")
    description: qsTr("Choose dark or light theme")
    showBackground: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: [
                { mode: "dark", label: qsTr("Dark") },
                { mode: "light", label: qsTr("Light") }
            ]

            delegate: StyledRect {
                required property var modelData
                Layout.fillWidth: true

                readonly property bool isCurrent: (modelData.mode === "dark" && !Colours.currentLight) || (modelData.mode === "light" && Colours.currentLight)

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Appearance.rounding.normal
                border.width: isCurrent ? 1 : 0
                border.color: Colours.palette.m3primary

                StateLayer {
                    function onClicked(): void {
                        Colours.setMode(modelData.mode);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    StyledRect {
                        Layout.alignment: Qt.AlignVCenter
                        width: 24
                        height: 24
                        radius: Appearance.rounding.full
                        color: modelData.mode === "dark" ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerLowest
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.label
                        font.pointSize: Appearance.font.size.normal
                        font.weight: isCurrent ? 500 : 400
                    }

                    Loader {
                        active: isCurrent
                        sourceComponent: MaterialIcon {
                            text: "check"
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.large
                        }
                    }
                }

                implicitHeight: 48
            }
        }
    }
}
