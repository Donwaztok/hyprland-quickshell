pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Math.max(Config.dashboard.sizes.dateTimeWidth, layout.implicitWidth + Appearance.padding.normal * 2)

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.small
        spacing: Appearance.spacing.small

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            StyledText {
                Layout.bottomMargin: -(font.pointSize * 0.4)
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.extraLarge
                font.family: Appearance.font.family.clock
                font.weight: Font.Bold
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "•••"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.extraLarge * 0.9
                font.family: Appearance.font.family.clock
            }

            StyledText {
                Layout.topMargin: -(font.pointSize * 0.4)
                Layout.alignment: Qt.AlignHCenter
                text: Time.minuteStr
                color: Colours.palette.m3secondary
                font.pointSize: Appearance.font.size.extraLarge
                font.family: Appearance.font.family.clock
                font.weight: Font.Bold
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter

                active: Config.services.useTwelveHourClock
                visible: active

                sourceComponent: StyledText {
                    text: Time.amPmStr
                    color: Colours.palette.m3secondary
                    font.pointSize: Appearance.font.size.small
                    font.family: Appearance.font.family.clock
                    font.weight: Font.Bold
                }
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width * 0.45, 28)
            Layout.preferredHeight: 3
            Layout.topMargin: Appearance.spacing.small
            Layout.bottomMargin: Appearance.spacing.small
            radius: Appearance.rounding.full
            color: Colours.palette.m3primary
            opacity: 0.8
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: Time.format("MMMM").toUpperCase()
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Colours.palette.m3secondary
                font.pointSize: Appearance.font.size.small
                font.letterSpacing: 2
                font.weight: Font.Bold
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("dd")
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.extraLarge
                font.letterSpacing: 1
                font.weight: Font.Medium
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: Time.format("dddd")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Colours.palette.m3secondary
                font.pointSize: Appearance.font.size.smaller
                font.letterSpacing: 1
            }
        }
    }
}
