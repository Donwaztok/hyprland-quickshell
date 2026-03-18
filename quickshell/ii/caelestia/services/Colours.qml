pragma Singleton
pragma ComponentBehavior: Bound

import caelestia.config
import caelestia.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool showPreview
    property string scheme
    property string flavour
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    readonly property alias wallLuminance: analyser.luminance

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function toCamelCase(str: string): string {
        return str.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            root.scheme = scheme.name;
            flavour = scheme.flavour;
            currentLight = scheme.mode === "light";
        } else {
            previewLight = scheme.mode === "light";
        }

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const camel = name.indexOf("_") >= 0 ? toCamelCase(name) : name;
            const propName = camel.startsWith("term") ? camel : `m3${camel}`;
            if (colours.hasOwnProperty(propName))
                colours[propName] = `#${colour}`;
        }
    }

    function setMode(mode: string): void {
        const scheme = (mode === "light") ? builtinSchemes.defaultLight : builtinSchemes.defaultDark;
        load(JSON.stringify(scheme), false);
        Config.appearance.themeMode = mode;
        Config.save();
    }

    function writeScheme(schemeObj: var): void {
        if (!schemeObj || !schemeObj.colours)
            return;
        let mode = schemeObj.mode;
        if (!mode && schemeObj.colours.background)
            mode = parseInt(String(schemeObj.colours.background).substring(0, 2), 16) < 0x80 ? "dark" : "light";
        mode = mode || "dark";
        const scheme = { name: schemeObj.name, flavour: schemeObj.flavour, mode: mode, colours: schemeObj.colours };
        load(JSON.stringify(scheme), false);
        Config.appearance.themeMode = mode;
        Config.save();
    }

    Component.onCompleted: {
        const mode = Config.appearance.themeMode || "dark";
        const scheme = (mode === "light") ? builtinSchemes.defaultLight : builtinSchemes.defaultDark;
        load(JSON.stringify(scheme), false);
    }

    readonly property var builtinSchemes: ({
        defaultDark: {
            name: "default",
            flavour: "tonalspot",
            mode: "dark",
            colours: {
                primary_paletteKeyColor: "FFD369",
                secondary_paletteKeyColor: "cac5c8",
                tertiary_paletteKeyColor: "d1c3c6",
                neutral_paletteKeyColor: "948f94",
                neutral_variant_paletteKeyColor: "49464a",
                background: "141313",
                onBackground: "ffffff",
                surface: "141313",
                surfaceDim: "141313",
                surfaceBright: "3a3939",
                surfaceContainerLowest: "0f0e0e",
                surfaceContainerLow: "1c1b1c",
                surfaceContainer: "201f20",
                surfaceContainerHigh: "2b2a2a",
                surfaceContainerHighest: "363435",
                onSurface: "ffffff",
                surfaceVariant: "49464a",
                onSurfaceVariant: "ffffff",
                outline: "948f94",
                outlineVariant: "49464a",
                primary: "FFD369",
                onPrimary: "3d3000",
                primaryContainer: "4a3f00",
                onPrimaryContainer: "ffe082",
                secondary: "cac5c8",
                onSecondary: "323032",
                secondaryContainer: "4d4b4d",
                onSecondaryContainer: "ece6e9",
                tertiary: "d1c3c6",
                onTertiary: "372e30",
                tertiaryContainer: "31292b",
                onTertiaryContainer: "c1b4b7",
                error: "ffb4ab",
                onError: "690005",
                errorContainer: "93000a",
                onErrorContainer: "ffdad6"
            }
        },
        defaultLight: {
            name: "default",
            flavour: "tonalspot",
            mode: "light",
            colours: {
                primary_paletteKeyColor: "7d3d56",
                secondary_paletteKeyColor: "6f4a52",
                tertiary_paletteKeyColor: "80543a",
                neutral_paletteKeyColor: "72666a",
                neutral_variant_paletteKeyColor: "7a6c70",
                background: "fef7f9",
                onBackground: "201318",
                surface: "fef7f9",
                surfaceDim: "ded8da",
                surfaceBright: "fef7f9",
                surfaceContainerLowest: "ffffff",
                surfaceContainerLow: "f8f1f3",
                surfaceContainer: "f2ebed",
                surfaceContainerHigh: "ece5e7",
                surfaceContainerHighest: "e6dfe1",
                onSurface: "201318",
                surfaceVariant: "514347",
                onSurfaceVariant: "524347",
                outline: "847377",
                outlineVariant: "d5c2c6",
                primary: "9d3d5c",
                onPrimary: "ffffff",
                primaryContainer: "ffd9e3",
                onPrimaryContainer: "3b071d",
                secondary: "8b5a64",
                onSecondary: "ffffff",
                secondaryContainer: "ffd9e3",
                onSecondaryContainer: "351f26",
                tertiary: "9c5f2a",
                onTertiary: "ffffff",
                tertiaryContainer: "ffdcc3",
                onTertiaryContainer: "351c00",
                error: "ba1a1a",
                onError: "ffffff",
                errorContainer: "ffdad6",
                onErrorContainer: "410002"
            }
        }
    })

    ImageAnalyser {
        id: analyser

        source: Wallpapers.current
    }

    component Transparency: QtObject {
        readonly property bool enabled: Appearance.transparency.enabled
        readonly property real base: Appearance.transparency.base - (root.light ? 0.1 : 0)
        readonly property real layers: Appearance.transparency.layers
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#FFD369"
        property color m3secondary_paletteKeyColor: "#cac5c8"
        property color m3tertiary_paletteKeyColor: "#d1c3c6"
        property color m3neutral_paletteKeyColor: "#948f94"
        property color m3neutral_variant_paletteKeyColor: "#49464a"
        property color m3background: "#141313"
        property color m3onBackground: "#ffffff"
        property color m3surface: "#141313"
        property color m3surfaceDim: "#141313"
        property color m3surfaceBright: "#3a3939"
        property color m3surfaceContainerLowest: "#0f0e0e"
        property color m3surfaceContainerLow: "#1c1b1c"
        property color m3surfaceContainer: "#201f20"
        property color m3surfaceContainerHigh: "#2b2a2a"
        property color m3surfaceContainerHighest: "#363435"
        property color m3onSurface: "#ffffff"
        property color m3surfaceVariant: "#49464a"
        property color m3onSurfaceVariant: "#ffffff"
        property color m3inverseSurface: "#e6e1e1"
        property color m3inverseOnSurface: "#313030"
        property color m3outline: "#948f94"
        property color m3outlineVariant: "#49464a"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#FFD369"
        property color m3primary: "#FFD369"
        property color m3onPrimary: "#3d3000"
        property color m3primaryContainer: "#4a3f00"
        property color m3onPrimaryContainer: "#ffe082"
        property color m3inversePrimary: "#615d63"
        property color m3secondary: "#cac5c8"
        property color m3onSecondary: "#323032"
        property color m3secondaryContainer: "#4d4b4d"
        property color m3onSecondaryContainer: "#ece6e9"
        property color m3tertiary: "#d1c3c6"
        property color m3onTertiary: "#372e30"
        property color m3tertiaryContainer: "#31292b"
        property color m3onTertiaryContainer: "#c1b4b7"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffe082"
        property color m3primaryFixedDim: "#FFD369"
        property color m3onPrimaryFixed: "#1d1b1f"
        property color m3onPrimaryFixedVariant: "#49454b"
        property color m3secondaryFixed: "#e6e1e4"
        property color m3secondaryFixedDim: "#cac5c8"
        property color m3onSecondaryFixed: "#1d1b1d"
        property color m3onSecondaryFixedVariant: "#484648"
        property color m3tertiaryFixed: "#eddfe1"
        property color m3tertiaryFixedDim: "#d1c3c6"
        property color m3onTertiaryFixed: "#211a1c"
        property color m3onTertiaryFixedVariant: "#4e4447"
        property color term0: "#EDE4E4"
        property color term1: "#B52755"
        property color term2: "#A97363"
        property color term3: "#AF535D"
        property color term4: "#A67F7C"
        property color term5: "#B2416B"
        property color term6: "#8D76AD"
        property color term7: "#272022"
        property color term8: "#0E0D0D"
        property color term9: "#B52755"
        property color term10: "#A97363"
        property color term11: "#AF535D"
        property color term12: "#A67F7C"
        property color term13: "#B2416B"
        property color term14: "#8D76AD"
        property color term15: "#221A1A"
    }
}
