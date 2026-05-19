hl.config({
    general = {
        col = {
            active_border = "rgba(91919177)",
            inactive_border = "rgba(47474755)",
        },
    },
    misc = {
        background_color = "rgba(131313FF)",
    },
})

hl.window_rule({
    name = "pinned-border",
    match = { pin = true },
    border_color = "rgba(FFD369AA) rgba(FFD36977)",
})
