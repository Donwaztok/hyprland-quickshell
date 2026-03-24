import QtQuick
import Quickshell

import "."
import qs.modules.common
import caelestia.config as CaelestiaCfg
import caelestia.modules.background as CaelestiaBackground
import qs.modules.ii.cheatsheet
import qs.modules.ii.mediaControls
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
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
    PanelLoader {
        extraCondition: CaelestiaCfg.Config.loaded
        component: CaelestiaLockPanel {}
    }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader {
        extraCondition: CaelestiaCfg.Config.loaded
        component: WallpaperLauncherBridge {}
    }
}
