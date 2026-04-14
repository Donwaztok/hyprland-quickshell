import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("General Settings")
        font.pointSize: Appearance.font.size.normal
    }

    SwitchRow {
        label: qsTr("Enabled")
        checked: root.rootItem.enabled
        onToggled: checked => {
            root.rootItem.enabled = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show on hover")
        checked: root.rootItem.showOnHover
        onToggled: checked => {
            root.rootItem.showOnHover = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show Dashboard tab")
        checked: root.rootItem.showDashboard
        onToggled: checked => {
            root.rootItem.showDashboard = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show Media tab")
        checked: root.rootItem.showMedia
        onToggled: checked => {
            root.rootItem.showMedia = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show Performance tab")
        checked: root.rootItem.showPerformance
        onToggled: checked => {
            root.rootItem.showPerformance = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show Weather tab")
        checked: root.rootItem.showWeather
        onToggled: checked => {
            root.rootItem.showWeather = checked;
            root.rootItem.saveConfig();
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small

        text: qsTr("Weather location")
        font.pointSize: Appearance.font.size.normal
        font.weight: 500
    }

    StyledText {
        Layout.fillWidth: true

        text: qsTr("City name, or latitude and longitude separated by a comma. Leave empty for automatic location (IP).")
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.small
        color: Colours.palette.m3onSurfaceVariant
    }

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

    readonly property string weatherApiDocsUrl: "https://open-meteo.com/en/docs"

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

        text: weatherApiDocsUrl
        wrapMode: Text.WrapAnywhere
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: Colours.palette.m3outline
    }

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
