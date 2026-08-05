pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property bool profilesOpen
    property bool showDisabled: false

    readonly property var visibleOutputs: Audio.outputEntries.filter(e => e.enabled || root.showDisabled)
    readonly property var visibleInputs: Audio.inputEntries.filter(e => e.enabled || root.showDisabled)

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2
    clip: true

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer

    function deviceIcon(entry: var): string {
        if (!entry)
            return "device_unknown";
        if (entry.isMonitor)
            return "hearing";
        if (!entry.isSink)
            return entry.enabled ? "mic" : "mic_off";
        const label = (entry.label || "").toLowerCase();
        if (label.includes("hdmi") || label.includes("displayport"))
            return "tv";
        if (label.includes("headphone") || label.includes("headset") || label.includes("stinger") || label.includes("cloud"))
            return "headphones";
        if (label.includes("bluetooth"))
            return "bluetooth_audio";
        return entry.selected ? "speaker" : "speaker_group";
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "graphic_eq"
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Audio devices")
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            IconButton {
                type: IconButton.Tonal
                icon: root.showDisabled ? "visibility" : "visibility_off"
                checked: root.showDisabled
                onClicked: root.showDisabled = !root.showDisabled
            }

            IconButton {
                type: IconButton.Tonal
                icon: "tune"
                checked: root.profilesOpen
                onClicked: {
                    root.profilesOpen = !root.profilesOpen;
                    if (root.profilesOpen && (!Audio.cards || Audio.cards.length === 0))
                        Audio.rescanDevices();
                }
            }

            Item {
                implicitWidth: refreshBtn.implicitWidth
                implicitHeight: refreshBtn.implicitHeight

                IconButton {
                    id: refreshBtn

                    anchors.centerIn: parent
                    type: IconButton.Tonal
                    icon: "refresh"
                    disabled: Audio.scanning
                    opacity: Audio.scanning ? 0 : 1
                    onClicked: Audio.rescanDevices()

                    Behavior on opacity {
                        Anim {}
                    }
                }

                CircularIndicator {
                    anchors.centerIn: parent
                    strokeWidth: Appearance.padding.small / 2
                    bgColour: "transparent"
                    implicitSize: refreshBtn.implicitHeight - Appearance.padding.small
                    running: Audio.scanning
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            MaterialIcon {
                text: "volume_up"
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Output")
                font.weight: 500
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        StyledText {
            visible: root.visibleOutputs.length === 0
            Layout.fillWidth: true
            text: qsTr("No output devices found")
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        Repeater {
            model: root.visibleOutputs

            DeviceRow {
                required property var modelData

                entry: modelData
            }
        }

        RowLayout {
            Layout.topMargin: Appearance.spacing.smaller
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            MaterialIcon {
                text: "mic"
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Input")
                font.weight: 500
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        StyledText {
            visible: root.visibleInputs.length === 0
            Layout.fillWidth: true
            text: qsTr("No input devices found")
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        Repeater {
            model: root.visibleInputs

            DeviceRow {
                required property var modelData

                entry: modelData
            }
        }
    }

    component DeviceRow: Item {
        id: device

        required property var entry

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Appearance.padding.small
        opacity: entry.enabled ? 1 : 0.55

        StateLayer {
            function onClicked(): void {
                Audio.selectEntry(device.entry);
            }
        }

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.smaller

            MaterialIcon {
                text: root.deviceIcon(device.entry)
                color: device.entry.selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fill: device.entry.selected ? 1 : 0
                font.pointSize: Appearance.font.size.normal
            }

            Rectangle {
                implicitWidth: 18
                implicitHeight: 18
                radius: Appearance.rounding.full
                color: "transparent"
                border.color: device.entry.selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                border.width: 2
                opacity: device.entry.enabled ? 1 : 0.5

                StyledRect {
                    anchors.centerIn: parent
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: Appearance.rounding.full
                    color: Qt.alpha(Colours.palette.m3primary, device.entry.selected ? 1 : 0)

                    Behavior on color {
                        CAnim {}
                    }
                }

                Behavior on border.color {
                    CAnim {}
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: device.entry.label
                font.pointSize: Appearance.font.size.smaller
                font.weight: device.entry.selected ? 500 : 400
                color: device.entry.enabled ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            IconButton {
                type: IconButton.Text
                icon: device.entry.enabled ? "power_settings_new" : "power_off"
                disabled: !device.entry.cardName && !device.entry.isMonitor
                inactiveOnColour: device.entry.enabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                onClicked: Audio.toggleEntryEnabled(device.entry)
            }
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
