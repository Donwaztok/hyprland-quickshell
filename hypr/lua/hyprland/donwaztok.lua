-- Donwaztok Files and Text (Quickshell FloatingWindow)
--
-- Qt FloatingWindow often misses modifiers and nav keys. These binds are
-- created at config load and only enabled while that window is focused.
-- Mouse back/forward do not consume the click, so other clients still
-- receive it. The file manager handles the button only while it is focused.
--
-- Do not call hl.bind or :remove from a focus event or a timer: Hyprland
-- 0.56.2 segfaults in CLuaKeybind::push.

local qs = require("lua.constants").qsCmd

local fm = { non_consuming = true }
local fmRelease = { release = true, non_consuming = true }
local te = { non_consuming = true, description = "Donwaztok Text: Find" }

local function activeTitle()
    local win = hl.get_active_window()
    if not win or not win.title then
        return ""
    end
    return win.title
end

local function fileManagerFocused()
    local title = activeTitle()
    if not title:find("Donwaztok", 1, true) then
        return false
    end
    return title:find("Files", 1, true) ~= nil
        or title:find("Open File", 1, true) ~= nil
        or title:find("Select Folder", 1, true) ~= nil
        or title:find("Save As", 1, true) ~= nil
        or title:find("Save Files", 1, true) ~= nil
end

local function textEditorFocused()
    return activeTitle():find(" — Text", 1, true) ~= nil
end

local filesBinds = {
    hl.bind("ALT + Left", hl.dsp.global("donwaztok:fileManagerBack"), fm),
    hl.bind("ALT + Right", hl.dsp.global("donwaztok:fileManagerForward"), fm),
    hl.bind("F5", hl.dsp.global("donwaztok:fileManagerRefresh"), fm),
    hl.bind("CTRL + X", hl.dsp.global("donwaztok:fileManagerCut"), fm),
    hl.bind("CTRL + Z", hl.dsp.global("donwaztok:fileManagerUndo"), fm),
    hl.bind("CTRL + H", hl.dsp.global("donwaztok:fileManagerToggleHidden"), fm),
    hl.bind("SHIFT + Delete", hl.dsp.global("donwaztok:fileManagerDeletePermanent"), fm),
    hl.bind("SHIFT + KP_Delete", hl.dsp.global("donwaztok:fileManagerDeletePermanent"), fm),
    hl.bind("Shift_L", hl.dsp.global("donwaztok:fileManagerShiftDown"), fm),
    hl.bind("Shift_L", hl.dsp.global("donwaztok:fileManagerShiftUp"), fmRelease),
    hl.bind("Shift_R", hl.dsp.global("donwaztok:fileManagerShiftDown"), fm),
    hl.bind("Shift_R", hl.dsp.global("donwaztok:fileManagerShiftUp"), fmRelease),
    hl.bind("Control_L", hl.dsp.global("donwaztok:fileManagerCtrlDown"), fm),
    hl.bind("Control_L", hl.dsp.global("donwaztok:fileManagerCtrlUp"), fmRelease),
    hl.bind("Control_R", hl.dsp.global("donwaztok:fileManagerCtrlDown"), fm),
    hl.bind("Control_R", hl.dsp.global("donwaztok:fileManagerCtrlUp"), fmRelease),
}

local textBinds = {
    hl.bind("CTRL + F", hl.dsp.exec_cmd(qs("ipc call textEditor find")), te),
}

local function setBindGroup(binds, enabled)
    for i = 1, #binds do
        binds[i]:set_enabled(enabled)
    end
end

local function syncScopedBinds()
    setBindGroup(filesBinds, fileManagerFocused())
    setBindGroup(textBinds, textEditorFocused())
end

syncScopedBinds()
hl.on("window.active", syncScopedBinds)
hl.on("window.title", syncScopedBinds)
hl.on("window.close", syncScopedBinds)

hl.bind("mouse:275", function()
    if fileManagerFocused() then
        hl.dispatch(hl.dsp.global("donwaztok:fileManagerBack"))
    end
end, { non_consuming = true })

hl.bind("mouse:276", function()
    if fileManagerFocused() then
        hl.dispatch(hl.dsp.global("donwaztok:fileManagerForward"))
    end
end, { non_consuming = true })
