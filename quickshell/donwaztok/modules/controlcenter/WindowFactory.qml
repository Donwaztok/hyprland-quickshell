pragma Singleton

import qs.components
import qs.services.shell
import qs.modules.controlcenter
import Quickshell
import QtQuick

Item {
    id: root

    function create(parent, props) {
        controlCenter.createObject(parent ?? dummy, props || {});
    }

    QtObject {
        id: dummy
    }

    Component {
        id: controlCenter

        FloatingWindow {
            id: win

            property alias active: cc.active

            color: ControlCenterChrome.shellBackdropColor

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight

            minimumSize.width: implicitWidth
            minimumSize.height: implicitHeight
            maximumSize.width: implicitWidth
            maximumSize.height: implicitHeight

            readonly property var activePaneInfo: PaneRegistry.getByLabel(cc.active)
            title: qsTr("Donwaztok Settings — %1").arg(activePaneInfo ? activePaneInfo.title : cc.active)

            ControlCenter {
                id: cc

                anchors.fill: parent
                screen: win.screen
                floating: true

                function close(): void {
                    win.destroy();
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
