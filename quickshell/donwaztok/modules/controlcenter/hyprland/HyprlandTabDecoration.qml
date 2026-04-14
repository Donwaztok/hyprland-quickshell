pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var ctl
    spacing: Appearance.spacing.normal
    Layout.fillWidth: true

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Blur and shadows")
        description: qsTr("Background blur and drop shadows behind windows.")

        SwitchRow {
            label: qsTr("Blur enabled")
            checked: ctl ? ctl.blurEnabled : false
            flatStyle: true
            onToggled: v => ctl.applyBlurEnabled(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Blur size")
            value: ctl ? ctl.blurSize : 8
            from: 1
            to: 20
            stepSize: 1
            decimals: 0
            suffix: ""
            opacity: ctl && ctl.blurEnabled ? 1 : 0.45
            validator: IntValidator {
                bottom: 1
                top: 20
            }

            onValueModified: newValue => ctl.applyBlurSize(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Blur passes")
            value: ctl ? ctl.blurPasses : 2
            from: 1
            to: 5
            stepSize: 1
            decimals: 0
            suffix: ""
            opacity: ctl && ctl.blurEnabled ? 1 : 0.45
            validator: IntValidator {
                bottom: 1
                top: 5
            }

            onValueModified: newValue => ctl.applyBlurPasses(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Drop shadow")
            checked: ctl ? ctl.dropShadow : false
            flatStyle: true
            onToggled: v => ctl.applyDropShadow(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Shadow range")
            value: ctl ? ctl.shadowRange : 0
            from: 0
            to: 40
            stepSize: 1
            decimals: 0
            suffix: " px"
            opacity: ctl && ctl.dropShadow ? 1 : 0.45
            validator: IntValidator {
                bottom: 0
                top: 40
            }

            onValueModified: newValue => ctl.applyShadowRange(newValue)
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Opacity")
        description: qsTr("Window transparency (0% = fully transparent, 100% = opaque).")

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Active window opacity")
            value: ctl ? ctl.activeOpacity * 100 : 100
            from: 0
            to: 100
            stepSize: 1
            decimals: 0
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }

            onValueModified: newValue => ctl.applyOpacity("decoration:active_opacity", newValue / 100)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Inactive window opacity")
            value: ctl ? ctl.inactiveOpacity * 100 : 100
            from: 0
            to: 100
            stepSize: 1
            decimals: 0
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }

            onValueModified: newValue => ctl.applyOpacity("decoration:inactive_opacity", newValue / 100)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Dim special workspace")
            value: ctl ? ctl.dimSpecial * 100 : 0
            from: 0
            to: 100
            stepSize: 1
            decimals: 0
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }

            onValueModified: newValue => ctl.applyOpacity("decoration:dim_special", newValue / 100)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Fullscreen opacity")
            value: ctl ? ctl.fullscreenOpacity * 100 : 100
            from: 0
            to: 100
            stepSize: 1
            decimals: 0
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }

            onValueModified: newValue => ctl.applyOpacity("decoration:fullscreen_opacity", newValue / 100)
        }
    }
}
