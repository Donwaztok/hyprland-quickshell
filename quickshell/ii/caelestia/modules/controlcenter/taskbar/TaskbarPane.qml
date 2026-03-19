pragma ComponentBehavior: Bound

import ".."
import "../components"
import caelestia.components
import caelestia.components.controls
import caelestia.components.effects
import caelestia.components.containers
import caelestia.services
import caelestia.config
import caelestia.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property string position: Config.bar.position ?? "left"
    property real barSize: Config.bar.size ?? 1.0
    property bool clockShowIcon: Config.bar.clock.showIcon ?? true
    property bool persistent: Config.bar.persistent ?? true
    property bool showOnHover: Config.bar.showOnHover ?? true
    property int dragThreshold: Config.bar.dragThreshold ?? 20
    property bool showAudio: Config.bar.status.showAudio ?? true
    property bool showMicrophone: Config.bar.status.showMicrophone ?? true
    property bool showKbLayout: Config.bar.status.showKbLayout ?? false
    property bool showNetwork: Config.bar.status.showNetwork ?? true
    property bool showWifi: Config.bar.status.showWifi ?? true
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
        Config.bar.size = root.barSize;
        Config.bar.clock.showIcon = root.clockShowIcon;
        Config.bar.persistent = root.persistent;
        Config.bar.showOnHover = root.showOnHover;
        Config.bar.dragThreshold = root.dragThreshold;
        Config.bar.status.showAudio = root.showAudio;
        Config.bar.status.showMicrophone = root.showMicrophone;
        Config.bar.status.showKbLayout = root.showKbLayout;
        Config.bar.status.showNetwork = root.showNetwork;
        Config.bar.status.showWifi = root.showWifi;
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
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal

        radius: taskbarBorder.innerRadius
        color: "transparent"

        Loader {
            id: taskbarLoader

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large

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

                spacing: Appearance.spacing.normal

                RowLayout {
                    spacing: Appearance.spacing.smaller

                    StyledText {
                        text: qsTr("Taskbar")
                        font.pointSize: Appearance.font.size.large
                        font.weight: 500
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("Position")
                        font.pointSize: Appearance.font.size.normal
                    }

                    RowLayout {
                        Layout.topMargin: Appearance.spacing.smaller
                        spacing: Appearance.spacing.small

                        ToggleButton {
                            toggled: root.position === "left"
                            icon: "west"
                            label: qsTr("Left")
                            onClicked: {
                                root.position = "left";
                                root.saveConfig();
                            }
                        }
                        ToggleButton {
                            toggled: root.position === "right"
                            icon: "east"
                            label: qsTr("Right")
                            onClicked: {
                                root.position = "right";
                                root.saveConfig();
                            }
                        }
                        ToggleButton {
                            toggled: root.position === "top"
                            icon: "north"
                            label: qsTr("Top")
                            onClicked: {
                                root.position = "top";
                                root.saveConfig();
                            }
                        }
                        ToggleButton {
                            toggled: root.position === "bottom"
                            icon: "south"
                            label: qsTr("Bottom")
                            onClicked: {
                                root.position = "bottom";
                                root.saveConfig();
                            }
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("Bar size")
                        font.pointSize: Appearance.font.size.normal
                    }

                    SectionContainer {
                        contentSpacing: Appearance.spacing.normal

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Bar size (%)")
                            value: root.barSize * 100
                            from: 50
                            to: 150
                            stepSize: 1
                            suffix: "%"
                            validator: IntValidator { bottom: 50; top: 150 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => {
                                root.barSize = newValue / 100;
                                root.saveConfig();
                            }
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("Status Icons")
                        font.pointSize: Appearance.font.size.normal
                    }

                    ConnectedButtonGroup {
                        rootItem: root

                        options: [
                            {
                                label: qsTr("Speakers"),
                                propertyName: "showAudio",
                                onToggled: function (checked) {
                                    root.showAudio = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Microphone"),
                                propertyName: "showMicrophone",
                                onToggled: function (checked) {
                                    root.showMicrophone = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Keyboard"),
                                propertyName: "showKbLayout",
                                onToggled: function (checked) {
                                    root.showKbLayout = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Network"),
                                propertyName: "showNetwork",
                                onToggled: function (checked) {
                                    root.showNetwork = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Wifi"),
                                propertyName: "showWifi",
                                onToggled: function (checked) {
                                    root.showWifi = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Bluetooth"),
                                propertyName: "showBluetooth",
                                onToggled: function (checked) {
                                    root.showBluetooth = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Battery"),
                                propertyName: "showBattery",
                                onToggled: function (checked) {
                                    root.showBattery = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Capslock"),
                                propertyName: "showLockStatus",
                                onToggled: function (checked) {
                                    root.showLockStatus = checked;
                                    root.saveConfig();
                                }
                            }
                        ]
                    }
                }

                RowLayout {
                    id: mainRowLayout
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    ColumnLayout {
                        id: leftColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.normal
                    }

                    ColumnLayout {
                        id: middleColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.normal

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Clock")
                                font.pointSize: Appearance.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Show clock icon")
                                checked: root.clockShowIcon
                                onToggled: checked => {
                                    root.clockShowIcon = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Bar Behavior")
                                font.pointSize: Appearance.font.size.normal
                            }

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

                            SectionContainer {
                                contentSpacing: Appearance.spacing.normal

                                SliderInput {
                                    Layout.fillWidth: true

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
                        }

                    }

                    ColumnLayout {
                        id: rightColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.normal

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Popouts")
                                font.pointSize: Appearance.font.size.normal
                            }

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

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Tray Settings")
                                font.pointSize: Appearance.font.size.normal
                            }

                            ConnectedButtonGroup {
                                rootItem: root

                                options: [
                                    {
                                        label: qsTr("Background"),
                                        propertyName: "trayBackground",
                                        onToggled: function (checked) {
                                            root.trayBackground = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Compact"),
                                        propertyName: "trayCompact",
                                        onToggled: function (checked) {
                                            root.trayCompact = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Recolour"),
                                        propertyName: "trayRecolour",
                                        onToggled: function (checked) {
                                            root.trayRecolour = checked;
                                            root.saveConfig();
                                        }
                                    }
                                ]
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Monitors")
                                font.pointSize: Appearance.font.size.normal
                            }

                            ConnectedButtonGroup {
                                rootItem: root
                                // max 3 options per line
                                rows: Math.ceil(root.monitorNames.length / 3)

                                options: root.monitorNames.map(e => ({
                                            label: qsTr(e),
                                            propertyName: `monitor${e}`,
                                            onToggled: function (_) {
                                                // if the given monitor is in the excluded list, it should be added back
                                                let addedBack = excludedScreens.includes(e);
                                                if (addedBack) {
                                                    const index = excludedScreens.indexOf(e);
                                                    if (index !== -1) {
                                                        excludedScreens.splice(index, 1);
                                                    }
                                                } else {
                                                    if (!excludedScreens.includes(e)) {
                                                        excludedScreens.push(e);
                                                    }
                                                }
                                                root.saveConfig();
                                            },
                                            state: !Strings.testRegexList(root.excludedScreens, e)
                                        }))
                            }
                        }
                    }
                }
            }
        }
    }
}
