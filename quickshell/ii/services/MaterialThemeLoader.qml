pragma Singleton
pragma ComponentBehavior: Bound

import caelestia.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 *
 * After wallpaper JSON is applied, Caelestia scheme (~/.config/caelestia + shell.json) overwrites
 * Appearance.m3colors so ii widgets match the Caelestia bar/drawers.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath

    // Omit *_paletteKeyColor / neutral_* — Caelestia M3Palette has them; ii Appearance.m3colors does not.
    readonly property var caelestiaM3Keys: [
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
        themeFileView.reload()
    }

    function applyCaelestiaPaletteToIi(): void {
        const src = Colours.current;
        const dst = Appearance.m3colors;
        for (const k of root.caelestiaM3Keys) {
            if (src[k] !== undefined)
                dst[k] = src[k];
        }
        dst.darkmode = !Colours.currentLight;
    }

    function applyColors(fileContent) {
        const json = JSON.parse(fileContent)
        for (const key in json) {
            if (json.hasOwnProperty(key)) {
                // Convert snake_case to CamelCase
                const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                const m3Key = `m3${camelCaseKey}`
                Appearance.m3colors[m3Key] = json[key]
            }
        }
        
        Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5)
        Qt.callLater(() => root.applyCaelestiaPaletteToIi())
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Connections {
        target: Colours
        function onSchemeApplied(): void {
            root.applyCaelestiaPaletteToIi()
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
        }
        onLoadFailed: root.resetFilePathNextTime();
    }
}
