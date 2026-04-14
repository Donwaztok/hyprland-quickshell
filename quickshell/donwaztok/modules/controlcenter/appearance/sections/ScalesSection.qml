pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Scales")
    showBackground: true
    gnomeListRow: true
    collapsible: false

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Padding scale")
            value: rootPane.paddingScale
            from: 0.5
            to: 2.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.5
                top: 2.0
            }

            onValueModified: newValue => {
                rootPane.paddingScale = newValue;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Rounding scale")
            value: rootPane.roundingScale
            from: 0.1
            to: 5.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.1
                top: 5.0
            }

            onValueModified: newValue => {
                rootPane.roundingScale = newValue;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Spacing scale")
            value: rootPane.spacingScale
            from: 0.1
            to: 2.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.1
                top: 2.0
            }

            onValueModified: newValue => {
                rootPane.spacingScale = newValue;
                rootPane.saveConfig();
            }
        }
    }
}
