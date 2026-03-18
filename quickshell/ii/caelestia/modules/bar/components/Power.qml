import caelestia.components
import caelestia.services
import caelestia.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities

    readonly property real sizeFactor: (Config.bar.size ?? 1)
    readonly property int padSm: Math.max(1, Math.round(Appearance.padding.small * sizeFactor))

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
            root.visibilities.session = !root.visibilities.session;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        text: "power_settings_new"
        color: Colours.palette.m3error
        font.bold: true
        font.pointSize: Appearance.font.size.normal
    }
}
