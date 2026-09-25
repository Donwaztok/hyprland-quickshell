--- Shared constants for Hyprland Lua config.
local M = {}

M.qsConfig = "donwaztok"

-- qs alone uses gtk3 so QIcon follows the GTK icon theme (Tela). Global
-- QT_QPA_PLATFORMTHEME stays xdgdesktopportal so other Qt apps keep the
-- Donwaztok FileChooser portal.
function M.qsCmd(args)
    return string.format(
        "QT_QPA_PLATFORMTHEME=gtk3 qs -c %s %s",
        M.qsConfig,
        args
    )
end

return M
