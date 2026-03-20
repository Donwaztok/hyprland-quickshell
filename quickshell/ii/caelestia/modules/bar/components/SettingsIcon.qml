import caelestia.components
import caelestia.modules.controlcenter
import caelestia.services
import caelestia.config
import Quickshell
import QtQuick

Item {
    id: root

    readonly property int padSm: Math.max(1, Math.round(Appearance.padding.small * Config.barThicknessScale))

    implicitWidth: icon.implicitHeight + padSm * 2
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + padSm * 2

        radius: Appearance.rounding.full

        function onClicked(): void {
            WindowFactory.create(null, {
                active: "dashboard"
            });
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        text: "settings"
        color: Colours.palette.m3onSurface
        font.bold: true
        font.pointSize: Appearance.font.size.normal * Config.barThicknessScale
    }
}
