pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

PreferencesGroup {
    id: root

    required property var rootPane

    Layout.fillWidth: true
    title: qsTr("Border")
    description: qsTr("Default corner radius and outline thickness for framed surfaces.")

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

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

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

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
