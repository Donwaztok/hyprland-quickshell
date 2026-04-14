import qs.components
import qs.services.shell
import qs.config
import qs.modules.controlcenter
import Quickshell
import QtQuick

StyledRect {
    id: root

    required property ShellScreen screen
    required property Session session

    implicitHeight: text.implicitHeight + Appearance.padding.normal
    color: Colours.tPalette.m3surfaceContainerLow

    StyledText {
        id: text

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        readonly property var paneInfo: PaneRegistry.getByLabel(root.session.active)

        text: qsTr("Donwaztok Settings — %1").arg(paneInfo ? paneInfo.title : root.session.active)
        font.pointSize: Appearance.font.size.larger
        font.weight: Font.DemiBold
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        implicitWidth: implicitHeight
        implicitHeight: closeIcon.implicitHeight + Appearance.padding.small

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                QsWindow.window.destroy();
            }
        }

        MaterialIcon {
            id: closeIcon

            anchors.centerIn: parent
            text: "close"
        }
    }
}
