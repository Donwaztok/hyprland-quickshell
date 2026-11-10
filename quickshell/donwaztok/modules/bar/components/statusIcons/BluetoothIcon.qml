pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Adapter state, plus one glyph per connected device in the status area (not in the tray's square slot).
ColumnLayout {
    id: root

    property color colour
    property bool inTray

    spacing: Math.max(1, Math.floor(Math.max(1, Math.round(Appearance.spacing.smaller * Config.barThicknessScale)) / 2))

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
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

    Repeater {
        model: ScriptModel {
            values: root.inTray ? [] : Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
        }

        MaterialIcon {
            id: device

            required property BluetoothDevice modelData

            Layout.alignment: Qt.AlignHCenter
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
