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
        title: qsTr("Pointer and focus")
        description: qsTr("Mouse, scroll, and focus policy.")

        OptionSelectRow {
            label: qsTr("Focus follows mouse")
            options: [
                {
                    text: qsTr("Disabled"),
                    value: "0"
                },
                {
                    text: qsTr("Enabled"),
                    value: "1"
                },
                {
                    text: qsTr("Loose"),
                    value: "2"
                }
            ]
            currentValue: ctl ? String(ctl.followMouse) : "1"

            onOptionChosen: value => ctl.applyFollowMouse(value)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Mouse sensitivity")
            value: ctl ? ctl.sensitivity : 0
            from: -1
            to: 1
            stepSize: 0.05
            decimals: 2
            suffix: ""

            onValueModified: newValue => ctl.applySensitivity(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Natural scroll (trackpad)")
            checked: ctl ? ctl.naturalScroll : false
            flatStyle: true
            onToggled: v => ctl.applyNaturalScroll(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Scroll factor")
            value: ctl ? ctl.scrollFactor : 1
            from: 0.1
            to: 3
            stepSize: 0.05
            decimals: 2
            suffix: "×"

            onValueModified: newValue => ctl.applyScrollFactor(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        OptionSelectRow {
            label: qsTr("Float switch override focus")
            options: [
                {
                    text: qsTr("Keep focus"),
                    value: "0"
                },
                {
                    text: qsTr("Move focus"),
                    value: "1"
                },
                {
                    text: qsTr("First floating"),
                    value: "2"
                }
            ]
            currentValue: ctl ? String(ctl.floatSwitchOverrideFocus) : "0"

            onOptionChosen: value => ctl.applyFloatSwitchOverride(value)
        }
    }
}
