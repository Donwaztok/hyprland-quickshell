-- Machine-specific window rule overrides

-- Steam / Proton
hl.window_rule({
    name = "wow-fullscreen",
    match = { class = "^steam_app_[0-9]+$", title = "^(World of Warcraft)$" },
    fullscreen = true,
})

hl.window_rule({
    name = "steam-no-anim",
    match = { class = "^steam_app_[0-9]+$" },
    no_anim = true,
    border_size = 0,
})

-- Android emulator
hl.window_rule({
    name = "emulator-title",
    match = { title = "^(Emulator)$" },
    opacity = "0 override",
    no_focus = true,
})

hl.window_rule({
    name = "emulator-class",
    match = { class = "^(Emulator)$" },
    float = true,
    no_blur = true,
    center = true,
})

-- Opacity tweaks (opacity must be a string, not a table)
local opacityRules = {
    { class = "^(code-oss)$", opacity = "0.98 0.98" },
    { class = "^([Cc]ode)$", opacity = "0.98 0.98" },
    { class = "^([Cc]ursor)$", opacity = "0.98 0.98" },
    { class = "^(code-url-handler)$", opacity = "0.95 0.95" },
    { class = "^(code-insiders-url-handler)$", opacity = "0.95 0.95" },
    { class = "^(kitty)$", opacity = "0.95 0.95" },
    { class = "^([Ss]team)$", opacity = "0.95 0.95" },
    { class = "^(steamwebhelper)$", opacity = "0.95 0.95" },
    { class = "^([Ss]potify)$", opacity = "0.95 0.95" },
    { class = "^((.*)Nautilus(.*))$", opacity = "0.95 0.95" },
    { class = "^(polkit-gnome-authentication-agent-1)$", opacity = "0.95 0.95" },
    { class = "^(org.freedesktop.impl.portal.desktop.gtk)$", opacity = "0.95 0.95" },
    { class = "^(org.freedesktop.impl.portal.desktop.hyprland)$", opacity = "0.95 0.95" },
    { initial_title = "^(Spotify(.*))$", opacity = "0.95 0.95" },
    { title = "^((.*)WhatsApp)$", opacity = "0.95 0.95" },
    { title = "^((.*)Thunderbird)$", opacity = "0.95 0.95" },
}

local floatOpacityClasses = {
    "^(nwg-look)$",
    "^(qt5ct)$",
    "^(qt6ct)$",
    "^(kvantummanager)$",
    "^(org.pulseaudio.pavucontrol)$",
    "^(blueman-manager)$",
    "^(nm-applet)$",
    "^(nm-connection-editor)$",
}

for i, spec in ipairs(opacityRules) do
    local match = {}
    local opacity = spec.opacity
    for k, v in pairs(spec) do
        if k ~= "opacity" then
            match[k] = v
        end
    end
    hl.window_rule({
        name = "opacity-" .. i,
        match = match,
        opacity = opacity,
    })
end

for i, class in ipairs(floatOpacityClasses) do
    hl.window_rule({
        name = "float-opacity-" .. i,
        match = { class = class },
        opacity = "0.95 0.95",
        float = true,
    })
end
