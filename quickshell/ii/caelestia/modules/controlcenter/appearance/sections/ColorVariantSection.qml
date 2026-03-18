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
    title: qsTr("Color variant")
    description: qsTr("Material theme variant")
    showBackground: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: M3Variants.list

            delegate: StyledRect {
                required property var modelData

                Layout.fillWidth: true

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, modelData.variant === Schemes.currentVariant ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Appearance.rounding.normal
                border.width: modelData.variant === Schemes.currentVariant ? 1 : 0
                border.color: Colours.palette.m3primary

                StateLayer {
                    function onClicked(): void {
                        const variant = modelData.variant;

                        if (CaelestiaCli.available) {
                            Schemes._currentVariantFromCli = variant;
                            CaelestiaCli.exec(["scheme", "set", "-v", variant]);
                        } else {
                            const builtin = Colours.currentLight ? Colours.builtinSchemes.defaultLight : Colours.builtinSchemes.defaultDark;
                            const raw = builtin.colours;
                            const coloursCopy = {};
                            for (const key in raw) {
                                if (raw.hasOwnProperty(key))
                                    coloursCopy[key] = raw[key];
                            }
                            Colours.writeScheme({
                                name: Colours.scheme,
                                flavour: variant,
                                mode: builtin.mode,
                                colours: coloursCopy
                            });
                            Schemes._currentVariantFromCli = variant;
                        }

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
                    id: variantRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.padding.normal

                    spacing: Appearance.spacing.normal

                    MaterialIcon {
                        text: modelData.icon
                        font.pointSize: Appearance.font.size.large
                        fill: modelData.variant === Schemes.currentVariant ? 1 : 0
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.weight: modelData.variant === Schemes.currentVariant ? 500 : 400
                    }

                    MaterialIcon {
                        visible: modelData.variant === Schemes.currentVariant
                        text: "check"
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.large
                    }
                }

                implicitHeight: variantRow.implicitHeight + Appearance.padding.normal * 2
            }
        }
    }
}
