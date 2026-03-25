pragma ComponentBehavior: Bound

import ".."
import "../../components"
import donwaztok.components
import donwaztok.components.controls
import donwaztok.components.containers
import donwaztok.services
import donwaztok.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Border")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border rounding")
            value: rootPane.borderRounding
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderRounding = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border thickness")
            value: rootPane.borderThickness
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderThickness = newValue;
                rootPane.saveConfig();
            }
        }
    }
}
