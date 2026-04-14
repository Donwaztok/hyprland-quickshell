pragma ComponentBehavior: Bound

import "."
import "components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    readonly property int rounding: floating ? 0 : Appearance.rounding.normal

    property alias floating: session.floating
    property alias active: session.active
    readonly property Session session: Session {
        id: session

        root: root
    }

    function close(): void {
    }

    implicitWidth: implicitHeight * Config.controlCenter.sizes.ratio
    implicitHeight: screen.height * Config.controlCenter.sizes.heightMult

    Rectangle {
        z: -1
        anchors.fill: parent
        color: ControlCenterChrome.canvasColor
        radius: root.floating ? 0 : root.rounding
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ControlCenterHeader {
            Layout.fillWidth: true
            session: root.session
            floating: root.floating
            sidebarWidth: navRail.sidebarWidth
            topRadius: root.rounding
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StyledRect {
                id: sidebarChrome

                Layout.fillHeight: true
                implicitWidth: navRail.implicitWidth
                bottomLeftRadius: root.rounding
                color: ControlCenterChrome.navRailSurface

                NavRail {
                    id: navRail

                    session: root.session
                    initialOpeningComplete: root.initialOpeningComplete
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, ControlCenterChrome.sidebarSeparatorOpacity)
            }

            Panes {
                id: panes

                Layout.fillWidth: true
                Layout.fillHeight: true

                topRightRadius: 0
                bottomRightRadius: root.rounding
                session: root.session
            }
        }
    }

    readonly property bool initialOpeningComplete: panes.initialOpeningComplete
}
