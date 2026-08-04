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

    required property var rootItem

    readonly property string weatherApiDocsUrl: "https://open-meteo.com/en/docs"

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Panel")
        description: qsTr("Turn the dashboard on, choose its edge, and whether it appears on hover.")

        SwitchRow {
            flatStyle: true
            label: qsTr("Enabled")
            checked: root.rootItem.dashboardEnabled
            onToggled: checked => {
                root.rootItem.dashboardEnabled = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Show on hover")
            checked: root.rootItem.showOnHover
            onToggled: checked => {
                root.rootItem.showOnHover = checked;
                root.rootItem.saveConfig();
            }
        }

        OptionSelectRow {
            Layout.fillWidth: true
            label: qsTr("Position")
            currentValue: root.rootItem.position
            options: [
                {
                    text: qsTr("Follow bar"),
                    value: "follow-bar"
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
                    text: qsTr("Left"),
                    value: "left"
                },
                {
                    text: qsTr("Right"),
                    value: "right"
                }
            ]
            onOptionChosen: v => {
                root.rootItem.position = v;
                root.rootItem.saveConfig();
            }
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Tabs")
        description: qsTr("Which tabs are shown in the dashboard.")

        SwitchRow {
            flatStyle: true
            label: qsTr("Show Dashboard tab")
            checked: root.rootItem.showDashboard
            onToggled: checked => {
                root.rootItem.showDashboard = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Show Media tab")
            checked: root.rootItem.showMedia
            onToggled: checked => {
                root.rootItem.showMedia = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Show Performance tab")
            checked: root.rootItem.showPerformance
            onToggled: checked => {
                root.rootItem.showPerformance = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Show Weather tab")
            checked: root.rootItem.showWeather
            onToggled: checked => {
                root.rootItem.showWeather = checked;
                root.rootItem.saveConfig();
            }
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Weather")
        description: qsTr("City name, or latitude and longitude separated by a comma. Leave empty for automatic location (IP).")

        StyledTextField {
            Layout.fillWidth: true
            placeholderText: qsTr("e.g. Lisbon or 38.72,-9.14")
            text: root.rootItem.weatherLocation
            selectByMouse: true

            onEditingFinished: {
                const t = text.trim();
                if (t !== root.rootItem.weatherLocation) {
                    root.rootItem.weatherLocation = t;
                    root.rootItem.saveConfig();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "open_in_new"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.small
            }

            CustomMouseArea {
                Layout.fillWidth: true
                implicitHeight: weatherApiLinkLabel.height
                cursorShape: Qt.PointingHandCursor

                onClicked: Qt.openUrlExternally(root.weatherApiDocsUrl)

                StyledText {
                    id: weatherApiLinkLabel

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Open-Meteo API documentation (forecast & geocoding)")
                    wrapMode: Text.WordWrap
                    font.pointSize: Appearance.font.size.small
                    font.underline: true
                    color: Colours.palette.m3primary
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.weatherApiDocsUrl
            wrapMode: Text.WrapAnywhere
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: Colours.palette.m3outline
        }
    }

    PreferencesGroup {
        Layout.fillWidth: true
        title: qsTr("Media and interaction")
        description: qsTr("How often the media tab refreshes and how sensitive dragging the dashboard is.")

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Media update interval")
            value: root.rootItem.mediaUpdateInterval
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
                root.rootItem.mediaUpdateInterval = Math.round(newValue);
                root.rootItem.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Drag threshold")
            value: root.rootItem.dragThreshold
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
                root.rootItem.dragThreshold = Math.round(newValue);
                root.rootItem.saveConfig();
            }
        }
    }
}
