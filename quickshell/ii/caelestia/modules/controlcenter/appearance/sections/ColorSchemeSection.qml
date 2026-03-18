pragma ComponentBehavior: Bound

import ".."
import "../../../launcher/services"
import caelestia.components
import caelestia.components.controls
import caelestia.components.containers
import caelestia.services
import caelestia.config
import caelestia.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    title: qsTr("Color scheme")
    description: qsTr("Available color schemes")
    showBackground: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: Schemes.list

            delegate: StyledRect {
                required property var modelData

                Layout.fillWidth: true

                readonly property string schemeKey: modelData.mode ? `${modelData.name} ${modelData.flavour} ${modelData.mode}` : `${modelData.name} ${modelData.flavour}`
                readonly property bool isCurrent: schemeKey === Schemes.currentScheme

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Appearance.rounding.normal
                border.width: isCurrent ? 1 : 0
                border.color: Colours.palette.m3primary

                StateLayer {
                    function onClicked(): void {
                        const name = modelData.name;
                        const flavour = modelData.flavour;
                        const schemeKey = modelData.mode ? `${name} ${flavour} ${modelData.mode}` : `${name} ${flavour}`;

                        Schemes._currentSchemeFromCli = schemeKey;
                        Colours.writeScheme(modelData);

                        Qt.callLater(() => {
                            reloadTimer.restart();
                        });
                    }
                }

                Timer {
                    id: reloadTimer
                    interval: 300
                    onTriggered: {
                        Schemes.reload();
                    }
                }

                RowLayout {
                    id: schemeRow

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal

                    spacing: Appearance.spacing.normal

                    StyledRect {
                        id: preview

                        Layout.alignment: Qt.AlignVCenter

                        border.width: 1
                        border.color: Qt.alpha(`#${modelData.colours?.outline}`, 0.5)

                        color: `#${modelData.colours?.surface}`
                        radius: Appearance.rounding.full
                        implicitWidth: iconPlaceholder.implicitWidth
                        implicitHeight: iconPlaceholder.implicitWidth

                        MaterialIcon {
                            id: iconPlaceholder
                            visible: false
                            text: "circle"
                            font.pointSize: Appearance.font.size.large
                        }

                        Item {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right

                            implicitWidth: parent.implicitWidth / 2
                            clip: true

                            StyledRect {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right

                                implicitWidth: preview.implicitWidth
                                color: `#${modelData.colours?.primary}`
                                radius: Appearance.rounding.full
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: (modelData.mode === "light" ? qsTr("Light") : modelData.mode === "dark" ? qsTr("Dark") : modelData.flavour) ?? ""
                            font.pointSize: Appearance.font.size.normal
                        }

                        StyledText {
                            text: modelData.mode ? (modelData.name + " · " + modelData.flavour) : (modelData.name ?? "")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline

                            elide: Text.ElideRight
                            anchors.left: parent.left
                            anchors.right: parent.right
                        }
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

                implicitHeight: schemeRow.implicitHeight + Appearance.padding.normal * 2
            }
        }
    }
}
