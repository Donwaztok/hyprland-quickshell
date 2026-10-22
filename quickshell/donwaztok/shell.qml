//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// QML2_IMPORT_PATH: set in hypr/hyprland/env.conf (must match this shell root)

// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1

import "modules/common"
import "services"
import "panelFamilies"

import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: root

    // Stuff for every panel family
    ReloadPopup {}

    Component.onCompleted: {
        ConflictKiller.load()
        Cliphist.refresh()
        Wallpapers.load()
        // bin/fm is not versioned; build it on first start (needs cargo).
        Quickshell.execDetached(["bash", "-c", `[ -x "$1/bin/fm" ] || "$1/scripts/files/fm-rs/build.sh" `
            + `|| notify-send -a Shell "File manager" "Building bin/fm failed; see scripts/files/fm-rs/build.sh"`,
            "_", Quickshell.shellPath("")])
    }


    DonwaztokFamily {}
}


