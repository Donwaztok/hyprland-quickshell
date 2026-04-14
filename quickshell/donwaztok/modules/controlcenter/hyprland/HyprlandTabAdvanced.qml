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
        title: qsTr("Animations")
        description: qsTr("Global animation toggle.")

        SwitchRow {
            label: qsTr("Animations enabled")
            checked: ctl ? ctl.animationsEnabled : true
            flatStyle: true
            onToggled: v => ctl.applyAnimations(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Animate manual resizes")
            checked: ctl ? ctl.animateManualResizes : false
            flatStyle: true
            onToggled: v => ctl.applyAnimateManualResizes(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Animate mouse window dragging")
            checked: ctl ? ctl.animateMouseWindowdragging : false
            flatStyle: true
            onToggled: v => ctl.applyAnimateMouseWindowdragging(v)
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Compositor and display")
        description: qsTr("Performance, tearing, and multi-monitor focus.")

        SwitchRow {
            label: qsTr("Allow tearing (reduce latency)")
            checked: ctl ? ctl.allowTearing : false
            flatStyle: true
            onToggled: v => ctl.applyAllowTearing(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Variable frame rate (VFR)")
            checked: ctl ? ctl.vfr : true
            flatStyle: true
            onToggled: v => ctl.applyVfr(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Mouse moves focus between monitors")
            checked: ctl ? ctl.mouseMoveFocusesMonitor : true
            flatStyle: true
            onToggled: v => ctl.applyMouseMoveFocusesMonitor(v)
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Gestures and branding")
        description: qsTr("Touch gestures and splash screen.")

        SwitchRow {
            label: qsTr("Workspace swipe gesture")
            checked: ctl ? ctl.workspaceSwipe : true
            flatStyle: true
            onToggled: v => ctl.applyWorkspaceSwipe(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            label: qsTr("Disable Hyprland logo on boot")
            checked: ctl ? ctl.disableHyprlandLogo : false
            flatStyle: true
            onToggled: v => ctl.applyDisableLogo(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Reload values from compositor")
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurface
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: ctl.refreshFromHyprland()
            }
        }
    }
}
