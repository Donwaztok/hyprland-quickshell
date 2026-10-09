pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.services.shell
import qs.config
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Column {
    id: root

    spacing: Appearance.spacing.normal
    width: Config.bar.sizes.batteryWidth

    StyledText {
        visible: UPower.displayDevice.isLaptopBattery || DeviceBatteries.devices.length === 0
        text: UPower.displayDevice.isLaptopBattery ? qsTr("Remaining: %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("No battery detected")
    }

    Column {
        width: parent.width
        visible: DeviceBatteries.devices.length > 0
        spacing: Appearance.spacing.small

        StyledText {
            text: qsTr("Wireless devices")
            font.weight: 500
        }

        Repeater {
            model: ScriptModel {
                values: DeviceBatteries.devices
            }

            RowLayout {
                required property var modelData

                width: root.width
                spacing: Appearance.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: modelData.icon
                    color: modelData.percent >= 0 && modelData.percent <= DeviceBatteries.lowLevel ? Colours.palette.m3error : Colours.palette.m3onSurface
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small / 4

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (modelData.percent < 0)
                                return modelData.detail || qsTr("Connected, no battery report");
                            if (modelData.state === "charging")
                                return qsTr("Charging · %1%").arg(modelData.percent);
                            if (modelData.state === "full")
                                return qsTr("Charged · %1%").arg(modelData.percent);
                            return qsTr("%1%").arg(modelData.percent);
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        visible: modelData.percent >= 0
                        radius: Appearance.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StyledRect {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Math.max(0, Math.min(modelData.percent, 100)) / 100
                            radius: Appearance.rounding.full
                            color: modelData.percent <= DeviceBatteries.lowLevel ? Colours.palette.m3error : Colours.palette.m3primary
                        }
                    }
                }
            }
        }
    }

    StyledText {
        visible: UPower.displayDevice.isLaptopBattery

        function formatSeconds(s: int, fallback: string): string {
            const day = Math.floor(s / 86400);
            const hr = Math.floor(s / 3600) % 60;
            const min = Math.floor(s / 60) % 60;

            let comps = [];
            if (day > 0)
                comps.push(`${day} days`);
            if (hr > 0)
                comps.push(`${hr} hours`);
            if (min > 0)
                comps.push(`${min} mins`);

            return comps.join(", ") || fallback;
        }

        text: qsTr("Time %1: %2").arg(UPower.onBattery ? "remaining" : "until charged").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating...") : formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!"))
    }

    StyledRect {
        visible: UPower.displayDevice.isLaptopBattery || DeviceBatteries.devices.length > 0
        width: parent.width
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    StyledText {
        text: qsTr("Power profile: %1").arg(PowerProfile.toString(PowerProfiles.profile))
    }

    Loader {
        anchors.horizontalCenter: parent.horizontalCenter

        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        height: active ? (item?.implicitHeight ?? 0) : 0

        sourceComponent: StyledRect {
            implicitWidth: child.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: child.implicitHeight + Appearance.padding.smaller * 2

            color: Colours.palette.m3error
            radius: Appearance.rounding.normal

            Column {
                id: child

                anchors.centerIn: parent

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Performance Degraded")
                        color: Colours.palette.m3onError
                        font.family: Appearance.font.family.mono
                        font.weight: 500
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                    color: Colours.palette.m3onError
                }
            }
        }
    }

    StyledRect {
        id: profiles

        property string current: {
            const p = PowerProfiles.profile;
            if (p === PowerProfile.PowerSaver)
                return saver.icon;
            if (p === PowerProfile.Performance)
                return perf.icon;
            return balance.icon;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: saver.implicitHeight + balance.implicitHeight + perf.implicitHeight + Appearance.padding.normal * 2 + Appearance.spacing.large * 2
        implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Appearance.padding.small * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        StyledRect {
            id: indicator

            color: Colours.palette.m3primary
            radius: Appearance.rounding.full
            state: profiles.current

            states: [
                State {
                    name: saver.icon

                    Fill {
                        item: saver
                    }
                },
                State {
                    name: balance.icon

                    Fill {
                        item: balance
                    }
                },
                State {
                    name: perf.icon

                    Fill {
                        item: perf
                    }
                }
            ]

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }

        Profile {
            id: saver

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small

            profile: PowerProfile.PowerSaver
            icon: "energy_savings_leaf"
        }

        Profile {
            id: balance

            anchors.centerIn: parent

            profile: PowerProfile.Balanced
            icon: "balance"
        }

        Profile {
            id: perf

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small

            profile: PowerProfile.Performance
            icon: "rocket_launch"
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        required property int profile

        implicitWidth: icon.implicitHeight + Appearance.padding.small * 2
        implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

        StateLayer {
            radius: Appearance.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            function onClicked(): void {
                PowerProfiles.profile = parent.profile;
            }
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            font.pointSize: Appearance.font.size.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {}
            }
        }
    }
}
