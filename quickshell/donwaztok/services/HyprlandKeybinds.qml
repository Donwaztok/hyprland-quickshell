pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Hyprland keybinds for the cheatsheet.
 * Reads live binds via `hyprctl binds -j` (Hyprland 0.55+ Lua config).
 * Categorize with: { description = "Category: what it does" }
 */
Singleton {
    id: root

    property var rawBinds: []
    property var sections: []
    property var keybinds: ({
        children: []
    })

    readonly property var categoryOrder: ["Shell", "Apps", "Window", "Utilities", "Media", "Session"]

    function modMaskToMods(modMask) {
        const mods = [];
        if (modMask & (1 << 2))
            mods.push("Ctrl");
        if (modMask & (1 << 6))
            mods.push("Super");
        if (modMask & (1 << 0))
            mods.push("Shift");
        if (modMask & (1 << 3))
            mods.push("Alt");
        if (modMask & (1 << 1))
            mods.push("Caps");
        if (modMask & (1 << 4))
            mods.push("Mod2");
        if (modMask & (1 << 5))
            mods.push("Mod3");
        if (modMask & (1 << 7))
            mods.push("Mod5");
        return mods;
    }

    function normalizeKey(key) {
        if (!key)
            return "";
        if (key.indexOf("mouse:") === 0 || key.indexOf("code:") === 0)
            return key;
        if (key.length === 1)
            return key.toUpperCase();
        if (key.indexOf("XF86") === 0)
            return key;

        const special = {
            "BACKSPACE": "BackSpace",
            "RETURN": "Return",
            "ESCAPE": "Escape",
            "PRINT": "Print",
            "DELETE": "Delete",
            "TAB": "Tab",
            "SPACE": "Space",
            "MINUS": "Minus",
            "EQUAL": "Equal",
            "PERIOD": "Period",
            "SLASH": "Slash",
            "HASH": "Hash",
            "SUPER_L": "Super_L",
            "SUPER_R": "Super_R",
            "BRACKETLEFT": "BracketLeft",
            "BRACKETRIGHT": "BracketRight",
            "LEFT": "Left",
            "RIGHT": "Right",
            "UP": "Up",
            "DOWN": "Down",
        };
        const upper = key.toUpperCase();
        if (special[upper])
            return special[upper];
        return key.charAt(0).toUpperCase() + key.slice(1).toLowerCase();
    }

    function groupIntoColumns(sections, columnCount) {
        const cols = [];
        const weights = [];
        for (let c = 0; c < columnCount; c++) {
            cols.push({
                children: [],
                keybinds: [],
                name: ""
            });
            weights.push(0);
        }

        for (let i = 0; i < sections.length; i++) {
            let minIdx = 0;
            for (let c = 1; c < columnCount; c++) {
                if (weights[c] < weights[minIdx])
                    minIdx = c;
            }
            cols[minIdx].children.push(sections[i]);
            weights[minIdx] += Math.max(1, sections[i].keybinds.length);
        }

        return {
            children: cols.filter(col => col.children.length > 0)
        };
    }

    function parseBinds(rawBinds) {
        const sectionsByName = {};
        const sectionOrder = [];

        for (let i = 0; i < rawBinds.length; i++) {
            const bind = rawBinds[i];
            let desc = (bind.description || "").trim();
            if (!desc || desc === "[hidden]")
                continue;

            let category = "General";
            let comment = desc;
            const colon = desc.indexOf(":");
            if (colon > 0) {
                category = desc.substring(0, colon).trim();
                comment = desc.substring(colon + 1).trim();
            }
            if (!comment)
                continue;

            if (!sectionsByName[category]) {
                sectionsByName[category] = {
                    name: category,
                    keybinds: [],
                    children: []
                };
                sectionOrder.push(category);
            }

            sectionsByName[category].keybinds.push({
                mods: root.modMaskToMods(bind.modmask || 0),
                key: root.normalizeKey(bind.key || ""),
                dispatcher: bind.dispatcher || "",
                params: bind.arg || "",
                comment: comment
            });
        }

        const sections = [];
        const seen = {};
        for (let i = 0; i < root.categoryOrder.length; i++) {
            const name = root.categoryOrder[i];
            if (sectionsByName[name]) {
                sections.push(sectionsByName[name]);
                seen[name] = true;
            }
        }
        for (let i = 0; i < sectionOrder.length; i++) {
            const name = sectionOrder[i];
            if (!seen[name])
                sections.push(sectionsByName[name]);
        }

        root.sections = sections;
        return root.groupIntoColumns(sections, 3);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded")
                getKeybinds.running = true;
        }
    }

    Process {
        id: getKeybinds
        running: true
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    root.rawBinds = Array.isArray(parsed) ? parsed : [];
                    root.keybinds = root.parseBinds(root.rawBinds);
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e);
                    root.rawBinds = [];
                    root.sections = [];
                    root.keybinds = {
                        children: []
                    };
                }
            }
        }
    }
}
