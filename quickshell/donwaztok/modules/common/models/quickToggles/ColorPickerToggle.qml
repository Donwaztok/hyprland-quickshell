import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: qsTr("Color picker")
    hasStatusText: false
    toggled: false
    icon: "colorize"

    mainAction: () => {
        delayedActionTimer.start();
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["hyprpicker", "-a"]);
        }
    }

    tooltipText: qsTr("Color picker")
}
