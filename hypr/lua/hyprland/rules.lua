-- Window and layer rules (order matters: later rules override earlier ones)
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- File / save dialogs
hl.window_rule({
    name = "file-dialogs",
    match = { title = "^(Open File|Select a File|Open Folder|Save As|Library|File Upload)(.*)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "wallpaper-picker",
    match = { title = "^(Choose wallpaper)(.*)$" },
    float = true,
    center = true,
    size = { "monitor_w*0.60", "monitor_h*0.65" },
})

hl.window_rule({
    name = "save-open-prompt",
    match = { title = "^(.*)(wants to save|wants to open)$" },
    float = true,
    center = true,
})

-- Modal popups
hl.window_rule({
    name = "modal-popups",
    match = { modal = true },
    float = true,
    center = true,
})

-- Pinentry
hl.window_rule({
    name = "pinentry-focus",
    match = { class = "^(pinentry-).*$" },
    stay_focused = true,
})

-- Polkit
hl.window_rule({
    name = "polkit",
    match = { class = "^(polkit-gnome-authentication-agent-1|lxpolkit|lxqt-policykit-agent)$" },
    float = true,
    center = true,
    size = { "monitor_w*0.42", "monitor_h*0.38" },
})

-- Small utilities
hl.window_rule({
    name = "small-utilities",
    match = {
        class = "^(blueberry\\.py|blueman-manager|guifetch|pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor)$",
    },
    float = true,
    center = true,
    size = { "monitor_w*0.45", "monitor_h*0.45" },
})

hl.window_rule({
    name = "donwaztok-settings",
    match = { title = "^(Donwaztok Settings)$" },
    float = true,
})

hl.window_rule({
    name = "shell-conflicts",
    match = { title = ".*Shell conflicts.*" },
    float = true,
})

-- GNOME Settings
hl.window_rule({
    name = "gnome-settings",
    match = { class = "^(org\\.gnome\\.Settings|Gnome-control-center)$" },
    float = true,
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.70" },
})

-- Desktop portals
hl.window_rule({
    name = "gtk-portal",
    match = { class = "^org\\.freedesktop\\.impl\\.portal\\.desktop\\.gtk$" },
    float = true,
    size = { "monitor_w*0.60", "monitor_h*0.65" },
})

hl.window_rule({
    name = "zotero",
    match = { class = "^(Zotero)$" },
    float = true,
    size = { "monitor_w*0.45", "monitor_h*0.45" },
})

-- Terminals & dev tools
hl.window_rule({
    name = "warp-terminal",
    match = { class = "^dev\\.warp\\.Warp$" },
    tile = true,
})

-- Picture-in-picture
hl.window_rule({
    name = "pip",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    move = { "monitor_w*0.73", "monitor_h*0.72" },
    size = { "monitor_w*0.25", "monitor_h*0.25" },
})

-- Video idle inhibit
hl.window_rule({
    name = "video-idle-inhibit",
    match = { class = "^(mpv|vlc|io.github.celluloid_player.Celluloid)$" },
    idle_inhibit = "fullscreen",
})

-- Wine
hl.window_rule({
    name = "wine-no-max",
    match = { class = "^(.*[Ww]inecfg.*|winecfg)$" },
    no_max_size = true,
})

-- Games / tearing
hl.window_rule({
    name = "exe-immediate",
    match = { title = ".*\\.exe" },
    immediate = true,
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "minecraft-immediate",
    match = { title = ".*[Mm]inecraft.*" },
    immediate = true,
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "steam-immediate",
    match = { class = "^steam_app_[0-9]+$" },
    immediate = true,
    idle_inhibit = "fullscreen",
})

-- JetBrains helper popups
hl.window_rule({
    name = "jetbrains-popups",
    match = {
        class = "^jetbrains-.*$",
        float = true,
        title = "^$|^\\s$|^win\\d+$",
    },
    no_initial_focus = true,
})

-- Tiled windows: no shadow
hl.window_rule({
    name = "tiled-no-shadow",
    match = { float = false },
    no_shadow = true,
})

hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })

-- Layer rules
hl.layer_rule({
    name = "layer-xray",
    match = { namespace = ".*" },
    xray = true,
})

hl.layer_rule({
    name = "layer-no-anim",
    match = { namespace = "^(walker|selection|overview|anyrun|osk|hyprpicker|noanim|indicator.*)$" },
    no_anim = true,
})

hl.layer_rule({
    name = "quickshell-no-anim",
    match = {
        namespace = "^quickshell:(actionCenter|cheatsheet|lockWindowPusher|polkit|regionSelector|screenshot|session|reloadPopup)$",
    },
    no_anim = true,
})

hl.layer_rule({
    name = "quickshell-popup-xray-off",
    match = { namespace = "^quickshell:popup$" },
    xray = false,
})

hl.layer_rule({
    name = "gtk4-layer-shell-no-anim",
    match = { namespace = "^gtk4-layer-shell$" },
    no_anim = true,
})
