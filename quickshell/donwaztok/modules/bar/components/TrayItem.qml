pragma ComponentBehavior: Bound

import qs.components.effects
import qs.services.shell
import qs.config
import qs.utils
import Quickshell.Services.SystemTray
import QtQuick
import "statusIcons"

// One tray slot: an app (SystemTrayItem) or a shell icon placed in the tray (its id, see utils/BarIcons.qml).
MouseArea {
    id: root

    required property var modelData
    readonly property bool isShell: typeof modelData === "string"
    // Bar.qml opens this popout when the slot is hovered.
    readonly property string popoutName: isShell ? (BarIcons.shell[modelData]?.popout ?? "") : `traymenu:${modelData?.id ?? ""}`

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))
    implicitHeight: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))

    onClicked: event => {
        if (root.isShell || !root.modelData)
            return; // shell icons open their popout on hover
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        anchors.fill: parent
        visible: !root.isShell
        // modelData turns null when the app leaves the tray, before the delegate is removed
        source: root.isShell ? "" : Icons.getTrayIcon(root.modelData?.id ?? "", root.modelData?.icon ?? "")
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour && !root.isShell
    }

    StatusIconView {
        anchors.centerIn: parent
        active: root.isShell
        iconId: root.isShell ? root.modelData : ""
        colour: Colours.palette.m3secondary
        inTray: true
    }
}
