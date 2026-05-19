--- Shared constants for Hyprland Lua config.
local M = {}

M.qsConfig = "donwaztok"

function M.qsCmd(args)
    return string.format("qs -c %s %s", M.qsConfig, args)
end

return M
