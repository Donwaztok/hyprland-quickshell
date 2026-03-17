import caelestia.components
import caelestia.components.effects
import caelestia.services
import caelestia.config
import caelestia.utils
import QtQuick

Item {
    id: root

    implicitWidth: Math.round(Appearance.font.size.large * 1.2)
    implicitHeight: Math.round(Appearance.font.size.large * 1.2)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    Loader {
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Math.round(Appearance.font.size.large * 1.6)
            implicitHeight: Math.round(Appearance.font.size.large * 1.6)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Appearance.font.size.large * 1.2)
            colour: Colours.palette.m3tertiary
        }
    }
}
