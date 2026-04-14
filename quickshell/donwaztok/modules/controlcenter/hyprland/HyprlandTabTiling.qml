pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// Layout, gaps, master/dwindle options, border resize.
ColumnLayout {
    id: root

    property var ctl
    spacing: Appearance.spacing.normal
    Layout.fillWidth: true

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Tiling and layout")
        description: qsTr("Workspace layout, gaps, borders, and corner rounding.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Default layout")
                font.weight: Font.Medium
                color: Colours.palette.m3onSurface
            }

            TextButton {
                text: qsTr("Dwindle")
                type: TextButton.Tonal
                inactiveColour: ctl && ctl.layoutMode === "dwindle" ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: ctl && ctl.layoutMode === "dwindle" ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                onClicked: ctl.applyLayout("dwindle")
            }

            TextButton {
                text: qsTr("Master")
                type: TextButton.Tonal
                inactiveColour: ctl && ctl.layoutMode === "master" ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: ctl && ctl.layoutMode === "master" ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                onClicked: ctl.applyLayout("master")
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: ctl.refreshFromHyprland()
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Inner gaps")
            value: ctl ? ctl.gapsIn : 0
            from: 0
            to: 64
            stepSize: 1
            decimals: 0
            suffix: " px"
            validator: IntValidator {
                bottom: 0
                top: 64
            }

            onValueModified: newValue => ctl.applyGapsIn(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Outer gaps")
            value: ctl ? ctl.gapsOut : 0
            from: 0
            to: 64
            stepSize: 1
            decimals: 0
            suffix: " px"
            validator: IntValidator {
                bottom: 0
                top: 64
            }

            onValueModified: newValue => ctl.applyGapsOut(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Window border size")
            value: ctl ? ctl.borderSize : 0
            from: 0
            to: 12
            stepSize: 1
            decimals: 0
            suffix: " px"
            validator: IntValidator {
                bottom: 0
                top: 12
            }

            onValueModified: newValue => ctl.applyBorder(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Window rounding")
            value: ctl ? ctl.rounding : 0
            from: 0
            to: 30
            stepSize: 1
            decimals: 0
            suffix: " px"
            validator: IntValidator {
                bottom: 0
                top: 30
            }

            onValueModified: newValue => ctl.applyRounding(newValue)
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Dwindle and master")
        description: qsTr("Layout-specific options (still apply when using the other layout; Hyprland may ignore some).")

        SwitchRow {
            label: qsTr("Dwindle: pseudotile focused window")
            checked: ctl ? ctl.dwindlePseudotile : false
            flatStyle: true
            onToggled: v => ctl.applyDwindlePseudotile(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Master layout factor")
            value: ctl ? ctl.masterMfact : 0.55
            from: 0.1
            to: 0.9
            stepSize: 0.01
            decimals: 2
            suffix: ""

            onValueModified: newValue => ctl.applyMasterMfact(newValue)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        OptionSelectRow {
            label: qsTr("Master stack orientation")
            options: [
                {
                    text: qsTr("Left"),
                    value: "left"
                },
                {
                    text: qsTr("Right"),
                    value: "right"
                },
                {
                    text: qsTr("Top"),
                    value: "top"
                },
                {
                    text: qsTr("Bottom"),
                    value: "bottom"
                },
                {
                    text: qsTr("Center"),
                    value: "center"
                }
            ]
            currentValue: ctl ? ctl.masterOrientation : "left"

            onOptionChosen: value => ctl.applyMasterOrientation(value)
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Window interaction")
        description: qsTr("Resize behavior near borders.")

        SwitchRow {
            label: qsTr("Resize windows by dragging borders")
            checked: ctl ? ctl.resizeOnBorder : false
            flatStyle: true
            onToggled: v => ctl.applyResizeOnBorder(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Extend border grab area")
            value: ctl ? ctl.extendBorderGrabArea : 0
            from: 0
            to: 64
            stepSize: 1
            decimals: 0
            suffix: " px"
            validator: IntValidator {
                bottom: 0
                top: 64
            }

            onValueModified: newValue => ctl.applyExtendGrab(newValue)
        }
    }
}
