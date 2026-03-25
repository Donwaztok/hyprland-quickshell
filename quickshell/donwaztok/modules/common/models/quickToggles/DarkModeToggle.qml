import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: qsTr("Dark Mode")
    statusText: Appearance.m3colors.darkmode ? qsTr("Dark") : qsTr("Light")

    toggled: Appearance.m3colors.darkmode
    icon: "contrast"
    
    mainAction: () => {
        if (Appearance.m3colors.darkmode) {
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
        } else {
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
        }
    }

    tooltipText: qsTr("Dark Mode")
}
