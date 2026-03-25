import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Toolbar {
    id: root

    property var action
    property var selectionMode
    signal dismiss()

    function desiredTabIndex(): int {
        return root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1;
    }

    function syncTabIndexFromMode(): void {
        const want = desiredTabIndex();
        if (modeTabs.currentIndex !== want)
            modeTabs.setCurrentIndex(want);
    }

    ToolbarTabBar {
        id: modeTabs
        tabButtonList: [
            {"icon": "activity_zone", "name": qsTr("Rect")},
            {"icon": "gesture", "name": qsTr("Circle")}
        ]

        Component.onCompleted: Qt.callLater(() => root.syncTabIndexFromMode())

        Connections {
            target: root
            function onSelectionModeChanged(): void {
                root.syncTabIndexFromMode();
            }
        }

        Connections {
            target: modeTabs
            function onCurrentIndexChanged(): void {
                const mode = modeTabs.currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
                if (root.selectionMode !== mode)
                    root.selectionMode = mode;
            }
        }
    }
}
