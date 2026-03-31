pragma ComponentBehavior: Bound

import qs.components
import qs.services.m3
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property int effectiveInnerWidth: Config.bar.sizes.thickness
    readonly property int spaceSm: Math.max(1, Math.round(Appearance.spacing.small * Config.barThicknessScale))
    readonly property int spaceS: Math.max(1, Math.round(Appearance.spacing.smaller * Config.barThicknessScale))
    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconColumn
    readonly property int networkBarIconSize: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))
    readonly property string barNetworkLinkSpeed: {
        Nmcli.activeEthernet;
        Nmcli.active;
        const d = Nmcli.activeEthernet ? Nmcli.ethernetDeviceDetails : Nmcli.wirelessDeviceDetails;
        return d && d.linkSpeed ? d.linkSpeed : "";
    }

    clip: !barVertical
    implicitWidth: barVertical ? root.effectiveInnerWidth : iconColumn.implicitWidth
    implicitHeight: barVertical ? (iconColumn.implicitHeight - (Config.bar.status.showLockStatus && !Hypr.capsLock && !Hypr.numLock ? iconColumn.spacing : 0)) : root.effectiveInnerWidth

    GridLayout {
        id: iconColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: barVertical ? parent.top : undefined
        anchors.bottom: barVertical ? parent.bottom : undefined
        anchors.verticalCenter: barVertical ? undefined : parent.verticalCenter
        anchors.margins: 0

        flow: root.barVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.barVertical ? -1 : 1
        columns: root.barVertical ? 1 : -1
        rowSpacing: root.spaceSm
        columnSpacing: root.spaceSm

        // Lock keys status
        WrappedLoader {
            name: "lockstatus"
            active: Config.bar.status.showLockStatus

            sourceComponent: ColumnLayout {
                spacing: 0

                Item {
                    implicitWidth: capslockIcon.implicitWidth
                    implicitHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0

                    MaterialIcon {
                        id: capslockIcon

                        anchors.centerIn: parent
                        pointSizeScale: Config.barThicknessScale

                        scale: Hypr.capsLock ? 1 : 0.5
                        opacity: Hypr.capsLock ? 1 : 0

                        text: "keyboard_capslock_badge"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }

                Item {
                    Layout.topMargin: Hypr.capsLock && Hypr.numLock ? iconColumn.spacing : 0

                    implicitWidth: numlockIcon.implicitWidth
                    implicitHeight: Hypr.numLock ? numlockIcon.implicitHeight : 0

                    MaterialIcon {
                        id: numlockIcon

                        anchors.centerIn: parent
                        pointSizeScale: Config.barThicknessScale

                        scale: Hypr.numLock ? 1 : 0.5
                        opacity: Hypr.numLock ? 1 : 0

                        text: "looks_one"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }
            }
        }

        // Audio icon
        WrappedLoader {
            name: "audio"
            active: Config.bar.status.showAudio

            sourceComponent: MaterialIcon {
                pointSizeScale: Config.barThicknessScale
                animate: true
                text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                color: root.colour
            }
        }

        // Microphone icon
        WrappedLoader {
            name: "audio"
            active: Config.bar.status.showMicrophone

            sourceComponent: MaterialIcon {
                pointSizeScale: Config.barThicknessScale
                animate: true
                text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                color: root.colour
            }
        }

        // Keyboard layout icon
        WrappedLoader {
            name: "kblayout"
            active: Config.bar.status.showKbLayout

            sourceComponent: StyledText {
                animate: true
                text: Hypr.kbLayout
                color: root.colour
                font.family: Appearance.font.family.mono
                font.pointSize: Math.max(6, Appearance.font.size.small * Config.barThicknessScale)
            }
        }

        // Unified network indicator (Material, same glyphs as the popout list).
        WrappedLoader {
            name: "network"
            active: Config.bar.status.showNetwork

            sourceComponent: Item {
                width: root.networkBarIconSize
                height: width

                MaterialIcon {
                    anchors.centerIn: parent
                    pointSizeScale: Config.barThicknessScale
                    animate: true
                    text: {
                        if (Nmcli.activeEthernet)
                            return "computer";
                        if (!Nmcli.wifiEnabled)
                            return "signal_wifi_off";
                        if (Nmcli.active)
                            return Icons.getNetworkIcon(Nmcli.active.strength ?? 0, Nmcli.active.isSecure);
                        return "wifi_off";
                    }
                    color: root.colour
                }

                HoverHandler {
                    id: barNetHover

                    onHoveredChanged: {
                        if (hovered && (Nmcli.activeEthernet || Nmcli.active))
                            Nmcli.refreshActiveDeviceDetails(null);
                    }
                }

                ToolTip.visible: barNetHover.hovered && root.barNetworkLinkSpeed.length > 0
                ToolTip.delay: 400
                ToolTip.text: qsTr("Velocidade") + "\n" + root.barNetworkLinkSpeed
            }
        }

        // Bluetooth section
        WrappedLoader {
            Layout.preferredHeight: implicitHeight

            name: "bluetooth"
            active: Config.bar.status.showBluetooth

            sourceComponent: ColumnLayout {
                spacing: Math.max(1, Math.floor(root.spaceS / 2))

                // Bluetooth icon
                MaterialIcon {
                    pointSizeScale: Config.barThicknessScale
                    animate: true
                    text: {
                        if (!Bluetooth.defaultAdapter?.enabled)
                            return "bluetooth_disabled";
                        if (Bluetooth.devices.values.some(d => d.connected))
                            return "bluetooth_connected";
                        return "bluetooth";
                    }
                    color: root.colour
                }

                // Connected bluetooth devices
                Repeater {
                    model: ScriptModel {
                        values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
                    }

                    MaterialIcon {
                        id: device

                        required property BluetoothDevice modelData

                        pointSizeScale: Config.barThicknessScale
                        animate: true
                        text: Icons.getBluetoothIcon(modelData?.icon)
                        color: root.colour
                        fill: 1

                        SequentialAnimation on opacity {
                            running: device.modelData?.state !== BluetoothDeviceState.Connected
                            alwaysRunToEnd: true
                            loops: Animation.Infinite

                            Anim {
                                from: 1
                                to: 0
                                duration: Appearance.anim.durations.large
                                easing.bezierCurve: Appearance.anim.curves.standardAccel
                            }
                            Anim {
                                from: 0
                                to: 1
                                duration: Appearance.anim.durations.large
                                easing.bezierCurve: Appearance.anim.curves.standardDecel
                            }
                        }
                    }
                }
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }
        }

        // Battery icon
        WrappedLoader {
            name: "battery"
            active: Config.bar.status.showBattery

            sourceComponent: MaterialIcon {
                pointSizeScale: Config.barThicknessScale
                animate: true
                text: {
                    if (!UPower.displayDevice.isLaptopBattery) {
                        if (PowerProfiles.profile === PowerProfile.PowerSaver)
                            return "energy_savings_leaf";
                        if (PowerProfiles.profile === PowerProfile.Performance)
                            return "rocket_launch";
                        return "balance";
                    }

                    const perc = UPower.displayDevice.percentage;
                    const charging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state);
                    if (perc === 1)
                        return charging ? "battery_charging_full" : "battery_full";
                    let level = Math.floor(perc * 7);
                    if (charging && (level === 4 || level === 1))
                        level--;
                    return charging ? `battery_charging_${(level + 3) * 10}` : `battery_${level}_bar`;
                }
                color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? root.colour : Colours.palette.m3error
                fill: 1
            }
        }
    }

    component WrappedLoader: Loader {
        required property string name

        Layout.alignment: root.barVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: active
    }
}
