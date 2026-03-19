pragma ComponentBehavior: Bound

import caelestia.components.effects
import caelestia.services
import caelestia.config
import caelestia.utils
import Quickshell.Services.SystemTray
import QtQuick

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))
    implicitHeight: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
