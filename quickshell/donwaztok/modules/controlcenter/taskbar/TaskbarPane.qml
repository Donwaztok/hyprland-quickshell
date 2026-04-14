pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property string position: Config.bar.position ?? "left"
    property int barThickness: Config.bar.sizes.thickness ?? 36
    property bool clockShowIcon: Config.bar.clock.showIcon ?? true
    property bool persistent: Config.bar.persistent ?? true
    property bool showOnHover: Config.bar.showOnHover ?? true
    property int dragThreshold: Config.bar.dragThreshold ?? 20
    property bool showAudio: Config.bar.status.showAudio ?? true
    property bool showMicrophone: Config.bar.status.showMicrophone ?? true
    property bool showKbLayout: Config.bar.status.showKbLayout ?? false
    property bool showNetwork: Config.bar.status.showNetwork ?? true
    property bool showBluetooth: Config.bar.status.showBluetooth ?? true
    property bool showBattery: Config.bar.status.showBattery ?? true
    property bool showLockStatus: Config.bar.status.showLockStatus ?? true
    property bool trayBackground: Config.bar.tray.background ?? false
    property bool trayCompact: Config.bar.tray.compact ?? false
    property bool trayRecolour: Config.bar.tray.recolour ?? false
    property bool popoutTray: Config.bar.popouts.tray ?? true
    property bool popoutStatusIcons: Config.bar.popouts.statusIcons ?? true
    property list<string> monitorNames: Hypr.monitorNames()
    property list<string> excludedScreens: Config.bar.excludedScreens ?? []

    anchors.fill: parent

    Component.onCompleted: {
        if (Config.bar.entries) {
            entriesModel.clear();
            for (let i = 0; i < Config.bar.entries.length; i++) {
                const entry = Config.bar.entries[i];
                if (entry.id === "activeWindow" || entry.id === "power" || entry.id === "logo")
                    continue;
                entriesModel.append({
                    id: entry.id,
                    enabled: entry.enabled !== false
                });
            }
        }
    }

    function saveConfig(entryIndex, entryEnabled) {
        Config.bar.position = root.position;
        Config.bar.sizes.thickness = root.barThickness;
        Config.bar.clock.showIcon = root.clockShowIcon;
        Config.bar.persistent = root.persistent;
        Config.bar.showOnHover = root.showOnHover;
        Config.bar.dragThreshold = root.dragThreshold;
        Config.bar.status.showAudio = root.showAudio;
        Config.bar.status.showMicrophone = root.showMicrophone;
        Config.bar.status.showKbLayout = root.showKbLayout;
        Config.bar.status.showNetwork = root.showNetwork;
        Config.bar.status.showBluetooth = root.showBluetooth;
        Config.bar.status.showBattery = root.showBattery;
        Config.bar.status.showLockStatus = root.showLockStatus;
        Config.bar.tray.background = root.trayBackground;
        Config.bar.tray.compact = root.trayCompact;
        Config.bar.tray.recolour = root.trayRecolour;
        Config.bar.popouts.tray = root.popoutTray;
        Config.bar.popouts.statusIcons = root.popoutStatusIcons;
        Config.bar.excludedScreens = root.excludedScreens;

        const entries = [];
        for (let i = 0; i < entriesModel.count; i++) {
            const entry = entriesModel.get(i);
            let enabled = entry.enabled;
            if (entryIndex !== undefined && i === entryIndex) {
                enabled = entryEnabled;
            }
            entries.push({
                id: entry.id,
                enabled: enabled
            });
        }
        Config.bar.entries = entries;
        Config.save();
    }

    ListModel {
        id: entriesModel
    }

    ClippingRectangle {
        id: taskbarClippingRect
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal

        radius: taskbarBorder.innerRadius
        color: "transparent"

        Loader {
            id: taskbarLoader

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal

            sourceComponent: taskbarContentComponent
        }
    }

    InnerBorder {
        id: taskbarBorder
        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }

    Component {
        id: taskbarContentComponent

        StyledFlickable {
            id: sidebarFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: sidebarLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: sidebarFlickable
            }

            ColumnLayout {
                id: sidebarLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Appearance.spacing.large

                SettingsHeader {
                    title: qsTr("Taskbar")
                    subtitle: qsTr("Edge position, system indicators, tray, and which monitors show the bar.")
                }

                PreferencesGroup {
                    title: qsTr("Position")
                    description: qsTr("Which edge of the screen the bar is attached to.")

                    OptionSelectRow {
                        Layout.fillWidth: true
                        label: qsTr("Edge")
                        currentValue: root.position
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
                            }
                        ]
                        onOptionChosen: v => {
                            root.position = v;
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Bar thickness")
                    description: qsTr("Height or width of the bar in pixels.")

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Thickness (px)")
                        value: root.barThickness
                        from: 28
                        to: 72
                        stepSize: 1
                        suffix: "px"
                        validator: IntValidator {
                            bottom: 28
                            top: 72
                        }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.barThickness = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Status icons")
                    description: qsTr("Which status indicators appear on the bar.")

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Speakers")
                        checked: root.showAudio
                        onToggled: checked => {
                            root.showAudio = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Microphone")
                        checked: root.showMicrophone
                        onToggled: checked => {
                            root.showMicrophone = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Keyboard layout")
                        checked: root.showKbLayout
                        onToggled: checked => {
                            root.showKbLayout = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Network")
                        checked: root.showNetwork
                        onToggled: checked => {
                            root.showNetwork = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Bluetooth")
                        checked: root.showBluetooth
                        onToggled: checked => {
                            root.showBluetooth = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Battery")
                        checked: root.showBattery
                        onToggled: checked => {
                            root.showBattery = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Caps lock")
                        checked: root.showLockStatus
                        onToggled: checked => {
                            root.showLockStatus = checked;
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Clock")
                    description: qsTr("Clock appearance on the bar.")

                    SwitchRow {
                        label: qsTr("Show clock icon")
                        checked: root.clockShowIcon
                        onToggled: checked => {
                            root.clockShowIcon = checked;
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Bar behavior")
                    description: qsTr("Visibility and drag sensitivity.")

                    SwitchRow {
                        label: qsTr("Persistent")
                        checked: root.persistent
                        onToggled: checked => {
                            root.persistent = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("Show on hover")
                        checked: root.showOnHover
                        onToggled: checked => {
                            root.showOnHover = checked;
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.small

                        label: qsTr("Drag threshold")
                        value: root.dragThreshold
                        from: 0
                        to: 100
                        suffix: "px"
                        validator: IntValidator {
                            bottom: 0
                            top: 100
                        }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)

                        onValueModified: newValue => {
                            root.dragThreshold = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Popouts")
                    description: qsTr("Whether tray and status popouts detach from the bar.")

                    SwitchRow {
                        label: qsTr("Tray")
                        checked: root.popoutTray
                        onToggled: checked => {
                            root.popoutTray = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("Status icons")
                        checked: root.popoutStatusIcons
                        onToggled: checked => {
                            root.popoutStatusIcons = checked;
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Tray")
                    description: qsTr("Tray layout and coloring.")

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Background")
                        checked: root.trayBackground
                        onToggled: checked => {
                            root.trayBackground = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Compact")
                        checked: root.trayCompact
                        onToggled: checked => {
                            root.trayCompact = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        flatStyle: true
                        label: qsTr("Recolour")
                        checked: root.trayRecolour
                        onToggled: checked => {
                            root.trayRecolour = checked;
                            root.saveConfig();
                        }
                    }
                }

                PreferencesGroup {
                    title: qsTr("Monitors")
                    description: qsTr("Turn off to hide the bar on that monitor.")

                    Repeater {
                        Layout.fillWidth: true
                        model: root.monitorNames

                        SwitchRow {
                            required property string modelData

                            flatStyle: true
                            label: modelData
                            checked: !Strings.testRegexList(root.excludedScreens, modelData)
                            onToggled: checked => {
                                let list = root.excludedScreens.slice();
                                const idx = list.indexOf(modelData);
                                if (checked) {
                                    if (idx !== -1)
                                        list.splice(idx, 1);
                                } else {
                                    if (idx === -1)
                                        list.push(modelData);
                                }
                                root.excludedScreens = list;
                                root.saveConfig();
                            }
                        }
                    }
                }
            }
        }
    }
}
