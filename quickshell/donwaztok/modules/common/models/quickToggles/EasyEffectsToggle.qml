import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: qsTr("EasyEffects")

    available: EasyEffects.available
    toggled: EasyEffects.active
    icon: "graphic_eq"

    Component.onCompleted: {
        EasyEffects.fetchActiveState()
    }

    mainAction: () => {
        EasyEffects.toggle()
    }

    altAction: () => {
        Quickshell.execDetached(["bash", "-c", "flatpak run com.github.wwmm.easyeffects || easyeffects"])
    }

    tooltipText: qsTr("EasyEffects | Right-click to configure")
}
