pragma Singleton
pragma ComponentBehavior: Bound

import qs.services.shell
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Shared state + single hyprctl fetch for all Hyprland sidebar panes.
Item {
    id: root

    width: 1
    height: 1
    visible: false

    property int gapsIn: 5
    property int gapsOut: 10
    property int borderSize: 2
    property int rounding: 10
    property string layoutMode: "dwindle"

    property bool blurEnabled: true
    property int blurSize: 8
    property int blurPasses: 2
    property bool dropShadow: true
    property int shadowRange: 4

    property real activeOpacity: 1
    property real inactiveOpacity: 0.95
    property real dimSpecial: 0.5
    property real fullscreenOpacity: 1

    property bool animationsEnabled: true
    property bool disableHyprlandLogo: false
    property bool vfr: true

    property int followMouse: 1
    property real sensitivity: 0

    property bool resizeOnBorder: false
    property int extendBorderGrabArea: 15

    property bool allowTearing: false
    property bool animateManualResizes: false
    property bool animateMouseWindowdragging: false
    property bool mouseMoveFocusesMonitor: true

    property bool naturalScroll: false
    property real scrollFactor: 1
    property int floatSwitchOverrideFocus: 0

    property bool workspaceSwipe: true
    property bool dwindlePseudotile: false
    property real masterMfact: 0.55
    property string masterOrientation: "left"

    property string fetchHint: ""

    readonly property int _optCount: 32

    function refreshFromHyprland() {
        hyprFetchProc.running = true;
    }

    function applyKeyword(option, value) {
        Quickshell.execDetached(["hyprctl", "keyword", option, value]);
    }

    function applyBool(option, v) {
        applyKeyword(option, v ? "true" : "false");
    }

    function applyGapsIn(v) {
        root.gapsIn = Math.round(v);
        applyKeyword("general:gaps_in", String(root.gapsIn));
    }

    function applyGapsOut(v) {
        root.gapsOut = Math.round(v);
        applyKeyword("general:gaps_out", String(root.gapsOut));
    }

    function applyBorder(v) {
        root.borderSize = Math.round(v);
        applyKeyword("general:border_size", String(root.borderSize));
    }

    function applyRounding(v) {
        root.rounding = Math.round(v);
        applyKeyword("decoration:rounding", String(root.rounding));
    }

    function applyLayout(mode) {
        root.layoutMode = mode;
        applyKeyword("general:layout", mode);
    }

    function applyBlurEnabled(v) {
        root.blurEnabled = v;
        applyBool("decoration:blur:enabled", v);
    }

    function applyBlurSize(v) {
        root.blurSize = Math.round(v);
        applyKeyword("decoration:blur:size", String(root.blurSize));
    }

    function applyBlurPasses(v) {
        root.blurPasses = Math.round(v);
        applyKeyword("decoration:blur:passes", String(root.blurPasses));
    }

    function applyDropShadow(v) {
        root.dropShadow = v;
        applyBool("decoration:drop_shadow", v);
    }

    function applyShadowRange(v) {
        root.shadowRange = Math.round(v);
        applyKeyword("decoration:shadow_range", String(root.shadowRange));
    }

    function applyOpacity(option, v) {
        const clamped = Math.max(0, Math.min(1, v));
        if (option === "decoration:active_opacity")
            root.activeOpacity = clamped;
        else if (option === "decoration:inactive_opacity")
            root.inactiveOpacity = clamped;
        else if (option === "decoration:dim_special")
            root.dimSpecial = clamped;
        else if (option === "decoration:fullscreen_opacity")
            root.fullscreenOpacity = clamped;
        applyKeyword(option, clamped.toFixed(4));
    }

    function applyAnimations(v) {
        root.animationsEnabled = v;
        applyBool("animations:enabled", v);
    }

    function applyDisableLogo(v) {
        root.disableHyprlandLogo = v;
        applyBool("misc:disable_hyprland_logo", v);
    }

    function applyVfr(v) {
        root.vfr = v;
        applyBool("misc:vfr", v);
    }

    function applyFollowMouse(choice) {
        root.followMouse = parseInt(choice, 10);
        applyKeyword("input:follow_mouse", String(root.followMouse));
    }

    function applySensitivity(v) {
        root.sensitivity = v;
        applyKeyword("input:sensitivity", v.toFixed(4));
    }

    function applyResizeOnBorder(v) {
        root.resizeOnBorder = v;
        applyBool("general:resize_on_border", v);
    }

    function applyExtendGrab(v) {
        root.extendBorderGrabArea = Math.round(v);
        applyKeyword("general:extend_border_grab_area", String(root.extendBorderGrabArea));
    }

    function applyAllowTearing(v) {
        root.allowTearing = v;
        applyBool("general:allow_tearing", v);
    }

    function applyAnimateManualResizes(v) {
        root.animateManualResizes = v;
        applyBool("misc:animate_manual_resizes", v);
    }

    function applyAnimateMouseWindowdragging(v) {
        root.animateMouseWindowdragging = v;
        applyBool("misc:animate_mouse_windowdragging", v);
    }

    function applyMouseMoveFocusesMonitor(v) {
        root.mouseMoveFocusesMonitor = v;
        applyBool("misc:mouse_move_focuses_monitor", v);
    }

    function applyNaturalScroll(v) {
        root.naturalScroll = v;
        applyBool("input:natural_scroll", v);
    }

    function applyScrollFactor(v) {
        root.scrollFactor = v;
        applyKeyword("input:scroll_factor", v.toFixed(4));
    }

    function applyFloatSwitchOverride(v) {
        root.floatSwitchOverrideFocus = parseInt(v, 10);
        applyKeyword("input:float_switch_override_focus", String(root.floatSwitchOverrideFocus));
    }

    function applyWorkspaceSwipe(v) {
        root.workspaceSwipe = v;
        applyBool("gestures:workspace_swipe", v);
    }

    function applyDwindlePseudotile(v) {
        root.dwindlePseudotile = v;
        applyBool("dwindle:pseudotile", v);
    }

    function applyMasterMfact(v) {
        root.masterMfact = v;
        applyKeyword("master:mfact", v.toFixed(4));
    }

    function applyMasterOrientation(value) {
        root.masterOrientation = value;
        applyKeyword("master:orientation", value);
    }

    function parseOptionJson(chunk) {
        const t = chunk.trim();
        if (!t.length)
            return null;
        try {
            const j = JSON.parse(t);
            if (j.int !== undefined)
                return j.int;
            if (j.float !== undefined)
                return j.float;
            if (j.str !== undefined)
                return j.str;
        } catch (e) {
            return null;
        }
        return null;
    }

    function parseOptionBool(chunk) {
        const v = parseOptionJson(chunk);
        if (v === null || v === undefined)
            return null;
        if (typeof v === "boolean")
            return v;
        if (typeof v === "number")
            return v !== 0;
        if (typeof v === "string") {
            const s = v.toLowerCase();
            return s === "true" || s === "yes" || s === "1";
        }
        return null;
    }

    function ingestFetchOutput(text) {
        const parts = text.split("__SPLIT__");
        const n = Math.min(parts.length, root._optCount);
        if (parts.length < 5) {
            root.fetchHint = qsTr("Could not read Hyprland options (is hyprctl available?)");
            return;
        }
        if (parts.length < root._optCount)
            root.fetchHint = qsTr("Some options could not be read; your Hyprland version may not expose every key.");
        else
            root.fetchHint = "";
        const a = i => {
            if (i < 0 || i >= n)
                return null;
            return parseOptionJson(parts[i].trim());
        };

        const g0 = a(0);
        const g1 = a(1);
        const g2 = a(2);
        const g3 = a(3);
        const g4 = a(4);
        if (g0 !== null && g0 !== undefined)
            root.gapsIn = g0;
        if (g1 !== null && g1 !== undefined)
            root.gapsOut = g1;
        if (g2 !== null && g2 !== undefined)
            root.borderSize = g2;
        if (g3 !== null && g3 !== undefined)
            root.rounding = g3;
        if (typeof g4 === "string" && g4.length)
            root.layoutMode = g4;

        const b5 = parseOptionBool(parts[5]);
        if (b5 !== null)
            root.blurEnabled = b5;
        const s6 = a(6);
        const s7 = a(7);
        if (s6 !== null && s6 !== undefined)
            root.blurSize = s6;
        if (s7 !== null && s7 !== undefined)
            root.blurPasses = s7;
        const b8 = parseOptionBool(parts[8]);
        if (b8 !== null)
            root.dropShadow = b8;
        const s9 = a(9);
        if (s9 !== null && s9 !== undefined)
            root.shadowRange = s9;

        const o10 = a(10);
        const o11 = a(11);
        const o12 = a(12);
        const o13 = a(13);
        if (typeof o10 === "number")
            root.activeOpacity = o10;
        if (typeof o11 === "number")
            root.inactiveOpacity = o11;
        if (typeof o12 === "number")
            root.dimSpecial = o12;
        if (typeof o13 === "number")
            root.fullscreenOpacity = o13;

        const b14 = parseOptionBool(parts[14]);
        if (b14 !== null)
            root.animationsEnabled = b14;
        const b15 = parseOptionBool(parts[15]);
        if (b15 !== null)
            root.disableHyprlandLogo = b15;
        const b16 = parseOptionBool(parts[16]);
        if (b16 !== null)
            root.vfr = b16;

        const fm = a(17);
        if (fm !== null && fm !== undefined)
            root.followMouse = fm;
        const sens = a(18);
        if (typeof sens === "number")
            root.sensitivity = sens;

        const b19 = parseOptionBool(parts[19]);
        if (b19 !== null)
            root.resizeOnBorder = b19;
        const ex = a(20);
        if (ex !== null && ex !== undefined)
            root.extendBorderGrabArea = ex;

        const b21 = parseOptionBool(parts[21]);
        if (b21 !== null)
            root.allowTearing = b21;
        const b22 = parseOptionBool(parts[22]);
        if (b22 !== null)
            root.animateManualResizes = b22;
        const b23 = parseOptionBool(parts[23]);
        if (b23 !== null)
            root.animateMouseWindowdragging = b23;
        const b24 = parseOptionBool(parts[24]);
        if (b24 !== null)
            root.mouseMoveFocusesMonitor = b24;
        const b25 = parseOptionBool(parts[25]);
        if (b25 !== null)
            root.naturalScroll = b25;
        const sf = a(26);
        if (typeof sf === "number")
            root.scrollFactor = sf;
        const fso = a(27);
        if (fso !== null && fso !== undefined)
            root.floatSwitchOverrideFocus = fso;
        const b28 = parseOptionBool(parts[28]);
        if (b28 !== null)
            root.workspaceSwipe = b28;
        const b29 = parseOptionBool(parts[29]);
        if (b29 !== null)
            root.dwindlePseudotile = b29;
        const mf = a(30);
        if (typeof mf === "number")
            root.masterMfact = mf;
        const mo = a(31);
        if (typeof mo === "string" && mo.length)
            root.masterOrientation = mo;
    }

    Process {
        id: hyprFetchProc

        running: false
        command: [
            "bash",
            "-c",
            "hyprctl -j getoption general:gaps_in 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:gaps_out 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:border_size 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:rounding 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:layout 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:blur:enabled 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:blur:size 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:blur:passes 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:drop_shadow 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:shadow_range 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:active_opacity 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:inactive_opacity 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:dim_special 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption decoration:fullscreen_opacity 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption animations:enabled 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption misc:disable_hyprland_logo 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption misc:vfr 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption input:follow_mouse 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption input:sensitivity 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:resize_on_border 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:extend_border_grab_area 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption general:allow_tearing 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption misc:animate_manual_resizes 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption misc:animate_mouse_windowdragging 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption misc:mouse_move_focuses_monitor 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption input:natural_scroll 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption input:scroll_factor 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption input:float_switch_override_focus 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption gestures:workspace_swipe 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption dwindle:pseudotile 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption master:mfact 2>/dev/null; echo __SPLIT__; "
                + "hyprctl -j getoption master:orientation 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ingestFetchOutput(text);
            }
        }
    }

    Timer {
        id: fetchTimer

        interval: 50
        repeat: false
        running: true
        onTriggered: hyprFetchProc.running = true
    }
}
