pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    signal schemeApplied()

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

    /**
     * One background for all shell chrome (Control Center, bar popouts, sidebar, session, etc.).
     * Same role as Material `m3surface` — no separate tint.
     */
    readonly property color shellSurface: palette.m3surface

    /** Last chosen primary seed (rrggbb), for accent swatch selection in UI. */
    property string accentSeedHex: "ffd369"

    /** Launcher / variant list: each name maps to a fixed accent seed (tonalspot base colours unchanged). */
    readonly property var materialVariantAccentSeeds: ({
        vibrant: "ec5b2a",
        tonalspot: "",
        expressive: "6d8769",
        fidelity: "5d9b17",
        content: "0aa36f",
        fruitsalad: "2f9f9f",
        rainbow: "1888ea",
        neutral: "7868d8",
        monochrome: "9e9e9e"
    })

    function layer(c: color, layer: var): color {
        return c;
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function toCamelCase(str: string): string {
        return str.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    }

    /** Maps JSON scheme keys to M3Palette property names (m3 + camelCase, except *_paletteKeyColor). */
    function schemeKeyToM3PropName(name: string): string {
        if (name.startsWith("term"))
            return name;
        if (name.endsWith("_paletteKeyColor"))
            return "m3" + name;
        if (name.indexOf("_") >= 0)
            return "m3" + toCamelCase(name);
        return "m3" + name;
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            root.scheme = scheme.name;
            flavour = scheme.flavour;
            currentLight = scheme.mode === "light";
            const pk = scheme.colours && scheme.colours.primary_paletteKeyColor;
            if (pk)
                root.accentSeedHex = normalizeSeedHex(String(pk));
        } else {
            previewLight = scheme.mode === "light";
        }

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const propName = schemeKeyToM3PropName(name);
            if (propName in colours)
                colours[propName] = `#${colour}`;
        }
        root.schemeApplied();
    }

    function setMode(mode: string): void {
        const scheme = (mode === "light") ? builtinSchemes.defaultLight : builtinSchemes.defaultDark;
        load(JSON.stringify(scheme), false);
        writePrimaryAccent(root.accentSeedHex, scheme.flavour);
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

    function normalizeSeedHex(s: string): string {
        let h = String(s || "").replace(/^#/, "").trim().toLowerCase();
        if (h.length === 3 && /^[0-9a-f]{3}$/.test(h))
            h = h.split("").map(ch => ch + ch).join("");
        return h.length === 6 && /^[0-9a-f]+$/.test(h) ? h : "";
    }

    function colourToRgbHex(col: color): string {
        const q = Qt.color(col);
        const r = Math.round(q.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(q.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(q.b * 255).toString(16).padStart(2, "0");
        return (r + g + b).toLowerCase();
    }

    /**
     * Keeps the built-in tonalspot surfaces/secondaries; only primary roles follow the seed.
     * @param flavourOpt passed to scheme.flavour (launcher / CLI); accent row uses tonalspot.
     */
    function writePrimaryAccent(seedHex: string, flavourOpt: string): void {
        const h = normalizeSeedHex(seedHex);
        if (!h)
            return;
        const light = root.currentLight;
        const flavourUse = flavourOpt || "tonalspot";
        const builtin = light ? builtinSchemes.defaultLight : builtinSchemes.defaultDark;
        const colours = {};
        for (const key in builtin.colours) {
            if (builtin.colours.hasOwnProperty(key))
                colours[key] = builtin.colours[key];
        }
        const c = Qt.color("#" + h);
        colours.primary_paletteKeyColor = h;
        colours.surfaceTint = h;
        /** Same vivid seed in light and dark — `m3primary` matches swatches / “original” accent. */
        colours.primary = h;
        colours.inversePrimary = h;
        colours.onPrimary = c.hslLightness > 0.58 ? "1e1b12" : "ffffff";
        const pCont = Qt.darker(c, 2.35);
        colours.primaryContainer = colourToRgbHex(pCont);
        colours.onPrimaryContainer = colourToRgbHex(Qt.lighter(pCont, 4.2));
        colours.primaryFixed = colourToRgbHex(Qt.lighter(c, 1.08));
        colours.primaryFixedDim = colourToRgbHex(Qt.darker(c, 1.12));
        colours.onPrimaryFixed = c.hslLightness > 0.54 ? "1d1607" : "ffffff";
        colours.onPrimaryFixedVariant = colourToRgbHex(Qt.darker(c, 1.75));

        root.accentSeedHex = h;
        writeScheme({
            name: root.scheme,
            flavour: flavourUse,
            mode: light ? "light" : "dark",
            colours: colours
        });
    }

    /** Variant names from launcher / CC: only shift primary accent to a preset seed for that style. */
    function writeMaterialVariant(variant: string): void {
        let seed = root.materialVariantAccentSeeds[variant];
        if (seed === undefined)
            seed = root.currentLight ? "c9a227" : "ffd369";
        if (seed === "")
            seed = root.currentLight ? "c9a227" : "ffd369";
        writePrimaryAccent(seed, variant);
    }

    Component.onCompleted: {
        const mode = Config.appearance.themeMode || "dark";
        const scheme = (mode === "light") ? builtinSchemes.defaultLight : builtinSchemes.defaultDark;
        load(JSON.stringify(scheme), false);
        /** One pass so light/dark both use the vivid seed as `primary` (matches swatches; builtin JSON may differ). */
        writePrimaryAccent(root.accentSeedHex, root.flavour);
    }

    readonly property var builtinSchemes: ({
        defaultDark: {
            name: "default",
            flavour: "tonalspot",
            mode: "dark",
            colours: {
                primary_paletteKeyColor: "ffd369",
                secondary_paletteKeyColor: "cac5c8",
                tertiary_paletteKeyColor: "d1c3c6",
                neutral_paletteKeyColor: "948f94",
                neutral_variant_paletteKeyColor: "49464a",
                background: "131313",
                onBackground: "e2e2e2",
                surface: "1c1b1c",
                surfaceDim: "0f0e0e",
                surfaceBright: "2b2a2a",
                surfaceContainerLowest: "0e0d0d",
                surfaceContainerLow: "1c1b1b",
                surfaceContainer: "201f20",
                surfaceContainerHigh: "2b2a2a",
                surfaceContainerHighest: "363435",
                onSurface: "e2e2e2",
                surfaceVariant: "49454f",
                onSurfaceVariant: "cac5ca",
                inverseSurface: "e6e1e1",
                inverseOnSurface: "313030",
                outline: "948f94",
                outlineVariant: "49464a",
                shadow: "000000",
                scrim: "000000",
                surfaceTint: "ffd369",
                primary: "ffd369",
                onPrimary: "1e1b12",
                primaryContainer: "524415",
                onPrimaryContainer: "f2e6b3",
                inversePrimary: "ffd369",
                secondary: "cac5c8",
                onSecondary: "323032",
                secondaryContainer: "4d4b4d",
                onSecondaryContainer: "ece6e9",
                tertiary: "d1c3c6",
                onTertiary: "372e30",
                tertiaryContainer: "31292b",
                onTertiaryContainer: "c1b4b7",
                primaryFixed: "ffe8a8",
                primaryFixedDim: "e6c258",
                onPrimaryFixed: "1d1607",
                onPrimaryFixedVariant: "6b5c2e",
                secondaryFixed: "e6e1e4",
                secondaryFixedDim: "cac5c8",
                onSecondaryFixed: "1d1b1d",
                onSecondaryFixedVariant: "484648",
                tertiaryFixed: "eddfe1",
                tertiaryFixedDim: "d1c3c6",
                onTertiaryFixed: "211a1c",
                onTertiaryFixedVariant: "4e4447",
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
                primary_paletteKeyColor: "c9a227",
                secondary_paletteKeyColor: "74777f",
                tertiary_paletteKeyColor: "6e7278",
                neutral_paletteKeyColor: "74777f",
                neutral_variant_paletteKeyColor: "767780",
                background: "f7f7f9",
                onBackground: "1b1b1f",
                surface: "f7f7f9",
                surfaceDim: "e4e4e9",
                surfaceBright: "f7f7f9",
                surfaceContainerLowest: "ffffff",
                surfaceContainerLow: "f0f0f4",
                surfaceContainer: "eaeaf0",
                surfaceContainerHigh: "e4e4ea",
                surfaceContainerHighest: "dedee5",
                onSurface: "1b1b1f",
                surfaceVariant: "e0e1e9",
                onSurfaceVariant: "45464f",
                inverseSurface: "303034",
                inverseOnSurface: "f4f4f6",
                outline: "777780",
                outlineVariant: "c4c6d0",
                shadow: "000000",
                scrim: "000000",
                surfaceTint: "c9a227",
                primary: "c9a227",
                onPrimary: "1e1b12",
                primaryContainer: "f1e6a8",
                onPrimaryContainer: "1f1b00",
                inversePrimary: "c9a227",
                secondary: "5c5f66",
                onSecondary: "ffffff",
                secondaryContainer: "e2e2e9",
                onSecondaryContainer: "1a1c21",
                tertiary: "5f6368",
                onTertiary: "ffffff",
                tertiaryContainer: "e1e3e9",
                onTertiaryContainer: "1a1d26",
                primaryFixed: "f0e4a0",
                primaryFixedDim: "d4c47a",
                onPrimaryFixed: "1d1900",
                onPrimaryFixedVariant: "4d4200",
                secondaryFixed: "e2e2e9",
                secondaryFixedDim: "c6c6d0",
                onSecondaryFixed: "1a1c21",
                onSecondaryFixedVariant: "44474e",
                tertiaryFixed: "e1e3e9",
                tertiaryFixedDim: "c5c8d0",
                onTertiaryFixed: "1a1d26",
                onTertiaryFixedVariant: "43474e",
                error: "ba1a1a",
                onError: "ffffff",
                errorContainer: "ffdad6",
                onErrorContainer: "410002"
            }
        }
    })

    component M3TPalette: QtObject {
        /** Primary / accent: never pass through wallpaper layer() — keeps same vivid hue as Colours.palette (esp. light mode). */
        readonly property color m3primary_paletteKeyColor: root.palette.m3primary_paletteKeyColor
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
        readonly property color m3surfaceTint: root.palette.m3surfaceTint
        readonly property color m3primary: root.palette.m3primary
        readonly property color m3onPrimary: root.palette.m3onPrimary
        readonly property color m3primaryContainer: root.palette.m3primaryContainer
        readonly property color m3onPrimaryContainer: root.palette.m3onPrimaryContainer
        readonly property color m3inversePrimary: root.palette.m3inversePrimary
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
        readonly property color m3primaryFixed: root.palette.m3primaryFixed
        readonly property color m3primaryFixedDim: root.palette.m3primaryFixedDim
        readonly property color m3onPrimaryFixed: root.palette.m3onPrimaryFixed
        readonly property color m3onPrimaryFixedVariant: root.palette.m3onPrimaryFixedVariant
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
        /** Shared with Appearance.m3colors (same object as `Colours.current`). */
        readonly property bool darkmode: !root.light
        property bool transparent: false

        property color m3primary_paletteKeyColor: "#ffd369"
        property color m3secondary_paletteKeyColor: "#cac5c8"
        property color m3tertiary_paletteKeyColor: "#d1c3c6"
        property color m3neutral_paletteKeyColor: "#948f94"
        property color m3neutral_variant_paletteKeyColor: "#49464a"
        property color m3background: "#131313"
        property color m3onBackground: "#e2e2e2"
        property color m3surface: "#1c1b1c"
        property color m3surfaceDim: "#0f0e0e"
        property color m3surfaceBright: "#2b2a2a"
        property color m3surfaceContainerLowest: "#0e0d0d"
        property color m3surfaceContainerLow: "#1c1b1b"
        property color m3surfaceContainer: "#201f20"
        property color m3surfaceContainerHigh: "#2b2a2a"
        property color m3surfaceContainerHighest: "#363435"
        property color m3onSurface: "#e2e2e2"
        property color m3surfaceVariant: "#49454f"
        property color m3onSurfaceVariant: "#cac5ca"
        property color m3inverseSurface: "#e6e1e1"
        property color m3inverseOnSurface: "#313030"
        property color m3outline: "#948f94"
        property color m3outlineVariant: "#49464a"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffd369"
        property color m3primary: "#ffd369"
        property color m3onPrimary: "#1e1b12"
        property color m3primaryContainer: "#524415"
        property color m3onPrimaryContainer: "#f2e6b3"
        property color m3inversePrimary: "#ffd369"
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
        property color m3primaryFixed: "#ffe8a8"
        property color m3primaryFixedDim: "#e6c258"
        property color m3onPrimaryFixed: "#1d1607"
        property color m3onPrimaryFixedVariant: "#6b5c2e"
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
        property color term3: "#FFD369"
        property color term4: "#A67F7C"
        property color term5: "#B2416B"
        property color term6: "#8D76AD"
        property color term7: "#272022"
        property color term8: "#0E0D0D"
        property color term9: "#B52755"
        property color term10: "#A97363"
        property color term11: "#FFD369"
        property color term12: "#A67F7C"
        property color term13: "#B2416B"
        property color term14: "#8D76AD"
        property color term15: "#221A1A"
    }
}
