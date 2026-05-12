pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var ctl
    spacing: Appearance.spacing.normal
    Layout.fillWidth: true

    function recoveryReasonLabel(code: string): string {
        if (code === "no_overlap")
            return qsTr("No monitor overlap");
        if (code === "center_off")
            return qsTr("Center off-screen");
        if (code === "no_overlap_tiled")
            return qsTr("No overlap (tiled)");
        return code;
    }

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
        title: qsTr("Window recovery")
        description: qsTr("Lists floating windows whose bounding box does not intersect any monitor, or whose center is outside all monitors. Use refresh after dragging; recovery moves them to the focused monitor.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Bring off-screen floating windows in")
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurface
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: HyprlandData.refreshRecoveryUi()
            }

            IconButton {
                icon: "filter_center_focus"
                type: IconButton.Text
                onClicked: HyprlandData.bringOffscreenFloatsInRequest()
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: (HyprlandData.recoveryCandidates && HyprlandData.recoveryCandidates.length > 0) ? qsTr("Detected:") : qsTr("No matching windows in the last hyprctl snapshot. Press refresh if you just moved a window.")
            font.pixelSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
        }

        Repeater {
            model: HyprlandData.recoveryCandidates ? HyprlandData.recoveryCandidates.length : 0

            delegate: RowLayout {
                required property int index

                readonly property var rec: HyprlandData.recoveryCandidates[index]

                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: (rec.class || "?") + " — " + (rec.title || "")
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WrapAnywhere
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.recoveryReasonLabel(rec.reason) + (rec.floating ? "" : (" · " + qsTr("set floating to move")))
                        font.pixelSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                IconButton {
                    visible: rec.floating
                    icon: "filter_center_focus"
                    type: IconButton.Text
                    onClicked: HyprlandData.bringOneWindowInRequest(rec.address)
                }
            }
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
