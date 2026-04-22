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
    title: qsTr("Fonts")
    description: qsTr("Global text size and which font families are used for icons, code, and UI.")

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Font size scale")
            value: rootPane.fontSizeScale
            from: 0.7
            to: 1.5
            decimals: 2
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.7
                top: 1.5
            }

            onValueModified: newValue => {
                rootPane.fontSizeScale = newValue;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.smaller
            Layout.bottomMargin: Appearance.spacing.smaller
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        FontFamilySelectRow {
            label: qsTr("Material font family")
            currentFamily: rootPane.fontFamilyMaterial
            onFamilyChosen: name => {
                rootPane.fontFamilyMaterial = name;
                rootPane.saveConfig();
            }
        }

        FontFamilySelectRow {
            label: qsTr("Monospace font family")
            currentFamily: rootPane.fontFamilyMono
            onFamilyChosen: name => {
                rootPane.fontFamilyMono = name;
                rootPane.saveConfig();
            }
        }

        FontFamilySelectRow {
            label: qsTr("Sans-serif font family")
            currentFamily: rootPane.fontFamilySans
            onFamilyChosen: name => {
                rootPane.fontFamilySans = name;
                rootPane.saveConfig();
            }
        }
    }
}
