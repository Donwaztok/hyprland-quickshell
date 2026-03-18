pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    property color colour: Colours.palette.m3tertiary

    implicitWidth: barVertical ? clockColumn.implicitWidth : clockRow.implicitWidth
    implicitHeight: barVertical ? clockColumn.implicitHeight : clockRow.implicitHeight

    Column {
        id: clockColumn

        visible: barVertical
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.clock.showIcon
            visible: active
            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(Config.services.useTwelveHourClock ? "hh\nmm\nA" : "hh\nmm")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }

    RowLayout {
        id: clockRow

        visible: !barVertical
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: Config.bar.clock.showIcon
            visible: active
            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.format(Config.services.useTwelveHourClock ? "h:mm A" : "HH:mm")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }
}
