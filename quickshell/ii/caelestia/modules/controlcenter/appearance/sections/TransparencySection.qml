pragma ComponentBehavior: Bound

import ".."
import "../../components"
import caelestia.components
import caelestia.components.controls
import caelestia.components.containers
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Transparency")
    showBackground: true

    SwitchRow {
        label: qsTr("Transparency enabled")
        checked: rootPane.transparencyEnabled
        onToggled: checked => {
            rootPane.transparencyEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency base")
            value: rootPane.transparencyBase * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyBase = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency layers")
            value: rootPane.transparencyLayers * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyLayers = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }
}
