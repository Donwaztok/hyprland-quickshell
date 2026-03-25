// Donwaztok panel family: M3 UI (donwaztok.* modules) + qs.modules.shell surfaces (OSD, polkit, region, cheatsheet).
import QtQuick
import Quickshell

import "."
import qs.modules.common
import donwaztok.modules.background as DwBackground
import qs.modules.shell.cheatsheet
import qs.modules.shell.onScreenDisplay
import qs.modules.shell.polkit
import qs.modules.shell.regionSelector
import "../donwaztok/modules" as DwCore
import "../donwaztok/modules/drawers" as DwDrawers

Scope {
    DwCore.Shortcuts {}
    DwDrawers.Drawers {}
    DwBackground.Background {}
    Cheatsheet {}
    DonwaztokLockPanel {}
    OnScreenDisplay {}
    Polkit {}
    RegionSelector {}
    WallpaperLauncherBridge {}
}
