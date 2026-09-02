pragma ComponentBehavior: Bound
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
import Quickshell.Widgets
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        if (GlobalStates.regionSelectorOpen)
            GlobalStates.regionSelectorOpen = false;
        // Always leave the cancel submap (close button / snip / Esc).
        Hyprland.dispatch('hl.dsp.submap("reset")');
    }

    function openSelector(action, selectionMode) {
        root.action = action;
        root.selectionMode = selectionMode;
        GlobalStates.regionSelectorOpen = true;
        Hyprland.dispatch('hl.dsp.submap("regionSelector")');
    }

    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners

    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData
            active: GlobalStates.regionSelectorOpen

            sourceComponent: RegionSelection {
                screen: regionSelectorLoader.modelData
                onDismiss: root.dismiss()
                action: root.action
                selectionMode: root.selectionMode
            }
        }
    }

    function screenshot() {
        root.openSelector(RegionSelection.SnipAction.Copy, RegionSelection.SelectionMode.RectCorners);
    }

    function search() {
        const mode = Config.options.search.imageSearch.useCircleSelection
            ? RegionSelection.SelectionMode.Circle
            : RegionSelection.SelectionMode.RectCorners;
        root.openSelector(RegionSelection.SnipAction.Search, mode);
    }

    function ocr() {
        root.openSelector(RegionSelection.SnipAction.CharRecognition, RegionSelection.SelectionMode.RectCorners);
    }

    IpcHandler {
        target: "region"

        function screenshot() {
            root.screenshot();
        }
        function search() {
            root.search();
        }
        function ocr() {
            root.ocr();
        }
        function dismiss() {
            root.dismiss();
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "regionScreenshot"
        description: "Takes a screenshot of the selected region"
        onPressed: root.screenshot()
    }
    GlobalShortcut {
        appid: "donwaztok"
        name: "regionSearch"
        description: "Searches the selected region"
        onPressed: root.search()
    }
    GlobalShortcut {
        appid: "donwaztok"
        name: "regionOcr"
        description: "Recognizes text in the selected region"
        onPressed: root.ocr()
    }
    GlobalShortcut {
        appid: "donwaztok"
        name: "regionDismiss"
        description: "Cancels the region selector"
        onPressed: root.dismiss()
    }
}
