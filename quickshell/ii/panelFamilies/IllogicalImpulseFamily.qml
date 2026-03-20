import QtQuick
import Quickshell

import qs.modules.common
import caelestia.config as CaelestiaCfg
import caelestia.modules.background as CaelestiaBackground
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.overlay
import qs.modules.ii.wallpaperSelector
import "../caelestia/modules" as CaelestiaCore
import "../caelestia/modules/drawers" as CaelestiaDrawers

Scope {
    PanelLoader { component: CaelestiaCore.Shortcuts {} }
    PanelLoader { component: CaelestiaDrawers.Drawers {} }
    PanelLoader {
        extraCondition: CaelestiaCfg.Config.loaded
        component: CaelestiaBackground.Background {}
    }
    PanelLoader { component: Cheatsheet {} }
    PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: WallpaperSelector {} }
}
