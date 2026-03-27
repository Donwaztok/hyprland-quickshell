pragma Singleton
pragma ComponentBehavior: Bound

import qs.services.m3
import qs.modules.common
import QtQuick
import Quickshell

/**
 * Syncs qs.services.m3 Colours into shared Appearance.m3colors (components under qs.components).
 * Palette values live in Colours.qml (builtinSchemes + M3Palette defaults) — no external JSON.
 */
Singleton {
    id: root

    readonly property var donwaztokM3Keys: [
        "m3background", "m3onBackground",
        "m3surface", "m3surfaceDim", "m3surfaceBright", "m3surfaceContainerLowest", "m3surfaceContainerLow",
        "m3surfaceContainer", "m3surfaceContainerHigh", "m3surfaceContainerHighest", "m3onSurface",
        "m3surfaceVariant", "m3onSurfaceVariant", "m3inverseSurface", "m3inverseOnSurface", "m3outline",
        "m3outlineVariant", "m3shadow", "m3scrim", "m3surfaceTint", "m3primary", "m3onPrimary",
        "m3primaryContainer", "m3onPrimaryContainer", "m3inversePrimary", "m3secondary", "m3onSecondary",
        "m3secondaryContainer", "m3onSecondaryContainer", "m3tertiary", "m3onTertiary", "m3tertiaryContainer",
        "m3onTertiaryContainer", "m3error", "m3onError", "m3errorContainer", "m3onErrorContainer",
        "m3success", "m3onSuccess", "m3successContainer", "m3onSuccessContainer", "m3primaryFixed",
        "m3primaryFixedDim", "m3onPrimaryFixed", "m3onPrimaryFixedVariant", "m3secondaryFixed",
        "m3secondaryFixedDim", "m3onSecondaryFixed", "m3onSecondaryFixedVariant", "m3tertiaryFixed",
        "m3tertiaryFixedDim", "m3onTertiaryFixed", "m3onTertiaryFixedVariant", "term0", "term1", "term2",
        "term3", "term4", "term5", "term6", "term7", "term8", "term9", "term10", "term11", "term12",
        "term13", "term14", "term15"
    ]

    function reapplyTheme() {
        applyDonwaztokPaletteToSharedUi()
    }

    function applyDonwaztokPaletteToSharedUi(): void {
        const src = Colours.current
        const dst = Appearance.m3colors
        for (const k of root.donwaztokM3Keys) {
            if (src[k] !== undefined)
                dst[k] = src[k]
        }
        dst.darkmode = !Colours.currentLight
    }

    Connections {
        target: Colours
        function onSchemeApplied(): void {
            root.applyDonwaztokPaletteToSharedUi()
        }
    }

    Component.onCompleted: Qt.callLater(() => root.applyDonwaztokPaletteToSharedUi())
}
