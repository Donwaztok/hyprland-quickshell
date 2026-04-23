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
    title: qsTr("Desktop clock")
    description: qsTr("Large clock on the wallpaper: visibility, position, shadow, and text contrast.")

    readonly property var _clockPosParts: (rootPane.desktopClockPosition || "bottom-right").split("-")
    readonly property string clockV: _clockPosParts[0] || "top"
    readonly property string clockH: _clockPosParts[1] || "left"

    readonly property var verticalOptions: [
        { text: qsTr("Top"), value: "top" },
        { text: qsTr("Middle"), value: "middle" },
        { text: qsTr("Bottom"), value: "bottom" }
    ]

    readonly property var horizontalOptions: [
        { text: qsTr("Left"), value: "left" },
        { text: qsTr("Center"), value: "center" },
        { text: qsTr("Right"), value: "right" }
    ]

    function setClockPos(v, h) {
        rootPane.desktopClockPosition = v + "-" + h;
        rootPane.saveConfig();
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        SwitchRow {
            flatStyle: true
            label: qsTr("Desktop clock enabled")
            checked: rootPane.desktopClockEnabled
            onToggled: checked => {
                rootPane.desktopClockEnabled = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.28)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.normal
            Layout.bottomMargin: Appearance.spacing.smaller
            text: qsTr("Position")
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurfaceVariant
        }

        OptionSelectRow {
            label: qsTr("Vertical")
            interactive: rootPane.desktopClockEnabled
            options: root.verticalOptions
            currentValue: root.clockV
            onOptionChosen: v => root.setClockPos(v, root.clockH)
        }

        OptionSelectRow {
            label: qsTr("Horizontal")
            interactive: rootPane.desktopClockEnabled
            options: root.horizontalOptions
            currentValue: root.clockH
            onOptionChosen: v => root.setClockPos(root.clockV, v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.28)
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Invert colors")
            checked: rootPane.desktopClockInvertColors
            onToggled: checked => {
                rootPane.desktopClockInvertColors = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.normal
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.smaller
            text: qsTr("Shadow")
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurfaceVariant
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Shadow enabled")
            checked: rootPane.desktopClockShadowEnabled
            onToggled: checked => {
                rootPane.desktopClockShadowEnabled = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.28)
        }

        SliderInput {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.smaller
            label: qsTr("Shadow opacity")
            value: rootPane.desktopClockShadowOpacity * 100
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
                rootPane.desktopClockShadowOpacity = newValue / 100;
                rootPane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Shadow blur")
            value: rootPane.desktopClockShadowBlur * 100
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
                rootPane.desktopClockShadowBlur = newValue / 100;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.normal
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.smaller
            text: qsTr("Clock text background")
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurfaceVariant
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Background behind clock text")
            checked: rootPane.desktopClockBackgroundEnabled
            onToggled: checked => {
                rootPane.desktopClockBackgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.28)
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Blur clock text background")
            checked: rootPane.desktopClockBackgroundBlur
            onToggled: checked => {
                rootPane.desktopClockBackgroundBlur = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.4 : 0.28)
        }

        SliderInput {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.smaller
            label: qsTr("Clock background opacity")
            value: rootPane.desktopClockBackgroundOpacity * 100
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
                rootPane.desktopClockBackgroundOpacity = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }
}
