hl.config({
    -- Border colors live in lua/hyprland/general.lua (avoid overriding them here).
    misc = {
        background_color = "rgba(131313FF)",
    },
})

hl.window_rule({
    name = "pinned-border",
    match = { pin = true },
    border_color = "rgba(FFD369AA) rgba(FFD36977)",
})
