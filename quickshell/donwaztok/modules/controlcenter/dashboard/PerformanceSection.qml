pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.components
import qs.components.controls
import qs.config
import qs.services.shell

ColumnLayout {
    id: root

    required property var rootItem
    readonly property bool gpuAvailable: SystemUsage.gpuType !== "NONE"
    readonly property bool batteryAvailable: UPower.displayDevice.isLaptopBattery

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Performance meters")
        description: qsTr("Choose which resource graphs appear in the performance tab.")

        SwitchRow {
            visible: root.batteryAvailable
            flatStyle: true
            label: qsTr("Battery")
            checked: root.rootItem.showBattery
            onToggled: checked => {
                root.rootItem.showBattery = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            visible: root.gpuAvailable
            flatStyle: true
            label: qsTr("GPU")
            checked: root.rootItem.showGpu
            onToggled: checked => {
                root.rootItem.showGpu = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("CPU")
            checked: root.rootItem.showCpu
            onToggled: checked => {
                root.rootItem.showCpu = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Memory")
            checked: root.rootItem.showMemory
            onToggled: checked => {
                root.rootItem.showMemory = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Storage")
            checked: root.rootItem.showStorage
            onToggled: checked => {
                root.rootItem.showStorage = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Network")
            checked: root.rootItem.showNetwork
            onToggled: checked => {
                root.rootItem.showNetwork = checked;
                root.rootItem.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Resource update interval")
            value: root.rootItem.resourceUpdateInterval
            from: 100
            to: 10000
            stepSize: 100
            suffix: "ms"
            validator: IntValidator {
                bottom: 100
                top: 10000
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                root.rootItem.resourceUpdateInterval = Math.round(newValue);
                root.rootItem.saveConfig();
            }
        }
    }
}
