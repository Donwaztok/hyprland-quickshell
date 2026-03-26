// Donwaztok panel family: M3 UI (qs.* modules) + qs.modules.shell surfaces (OSD, polkit, region, cheatsheet).
import QtQuick
import Quickshell

import "."
import qs.modules.common
import qs.modules.background as DwBackground
import qs.modules.shell.cheatsheet
import qs.modules.shell.onScreenDisplay
import qs.modules.shell.polkit
import qs.modules.shell.regionSelector
import qs.modules as DwCore
import qs.modules.drawers as DwDrawers

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
