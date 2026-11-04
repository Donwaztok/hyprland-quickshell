-- Custom keybinds
-- https://wiki.hypr.land/Configuring/Basics/Binds/
--
-- Cheatsheet (Super+/): use { description = "Category: what it does" }
-- Omit description (or leave it empty) to hide a bind from the list.

local windowLayout = "~/.config/hypr/custom/scripts/window_layout.py "
hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd(windowLayout .. "save"), { description = "Window: Save layout" })
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd(windowLayout .. "restore"), { description = "Window: Restore layout" })
