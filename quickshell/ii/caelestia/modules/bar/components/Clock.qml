pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property int spaceSm: Math.max(1, Math.round(Appearance.spacing.small * Config.barThicknessScale))
    property color colour: Colours.palette.m3tertiary

    implicitWidth: barVertical ? clockColumn.implicitWidth : clockRow.implicitWidth
    implicitHeight: barVertical ? clockColumn.implicitHeight : clockRow.implicitHeight

    Column {
        id: clockColumn

        visible: barVertical
        anchors.centerIn: parent
        spacing: root.spaceSm

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.clock.showIcon
            visible: active
            sourceComponent: MaterialIcon {
                pointSizeScale: Config.barThicknessScale
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(Config.services.useTwelveHourClock ? "hh\nmm\nA" : "hh\nmm")
            font.pointSize: Math.max(5, Appearance.font.size.smaller * Config.barThicknessScale)
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }

    RowLayout {
        id: clockRow

        visible: !barVertical
        anchors.centerIn: parent
        spacing: root.spaceSm

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: Config.bar.clock.showIcon
            visible: active
            sourceComponent: MaterialIcon {
                pointSizeScale: Config.barThicknessScale
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.format(Config.services.useTwelveHourClock ? "h:mm A" : "HH:mm")
            font.pointSize: Math.max(5, Appearance.font.size.smaller * Config.barThicknessScale)
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }
}
