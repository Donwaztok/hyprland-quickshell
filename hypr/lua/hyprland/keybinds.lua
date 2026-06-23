local qs = require("lua.constants").qsCmd
local hidden = { description = "[hidden]" }

local home = os.getenv("HOME") or ""
local launchScript = home .. "/.config/hypr/hyprland/scripts/launch_first_available.sh"
local terminalApps = '"${TERMINAL}" "kitty -1" "foot" "alacritty" "wezterm" "konsole" "kgx" "uxterm" "xterm"'

-- Shell (must stay on top)
hl.bind("SUPER + Space", hl.dsp.global("donwaztok:launcher"), {
    description = "Open launcher",
    release = true,
})
hl.bind("SUPER + V", hl.dsp.global("donwaztok:launcherOpenClipboard"), {
    description = "Clipboard history >> clipboard",
    release = true,
})
hl.bind("SUPER + Slash", hl.dsp.global("donwaztok:cheatsheetToggle"), { description = "Toggle cheatsheet" })
hl.bind(
    "SUPER + Backspace",
    hl.dsp.exec_cmd(qs("ipc call drawers toggle session")),
    { description = "Toggle session menu" }
)

hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd(qs("ipc call brightness increment") .. " || brightnessctl s 5%+"),
    { locked = true, repeating = true, description = "[hidden]" }
)
hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd(qs("ipc call brightness decrement") .. " || brightnessctl s 5%-"),
    { locked = true, repeating = true, description = "[hidden]" }
)
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5"),
    { locked = true, repeating = true, description = "[hidden]" }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
    { locked = true, repeating = true, description = "[hidden]" }
)

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true, description = "[hidden]" })
hl.bind(
    "SUPER + SHIFT + M",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"),
    { locked = true, description = "Toggle mute" }
)
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true, description = "[hidden]" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true, description = "[hidden]" })
hl.bind(
    "SUPER + ALT + M",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"),
    { locked = true, description = "Toggle mic" }
)

hl.bind("CTRL + SUPER + T", hl.dsp.global("donwaztok:wallpaperSelectorToggle"), { description = "Toggle Donwaztok launcher (wallpaper)" })
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.global("donwaztok:wallpaperSelectorRandom"), { description = "Random wallpaper (Donwaztok)" })
hl.bind(
    "CTRL + SUPER + R",
    hl.dsp.exec_cmd("killall ags agsv1 gjs ydotool qs quickshell; " .. qs("&")),
    { description = "Restart quickshell" }
)

-- Utilities
hl.bind("SUPER + SHIFT + S", hl.dsp.global("donwaztok:regionScreenshot"), { description = "Screen snip" })
hl.bind("SUPER + SHIFT + A", hl.dsp.global("donwaztok:regionSearch"), { description = "Google Lens snip" })
hl.bind("SUPER + SHIFT + X", hl.dsp.global("donwaztok:regionOcr"), { description = "OCR region >> clipboard" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Color picker" })

hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, description = "[hidden]" })
hl.bind(
    "CTRL + Print",
    hl.dsp.exec_cmd(
        "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && grim $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
    ),
    { locked = true, non_consuming = true, description = "Screenshot >> clipboard & file (file)" }
)
hl.bind("CTRL + Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, non_consuming = true, description = "[hidden]" })

-- Window
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true, description = "[hidden]" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("SUPER + Left", hl.dsp.focus({ direction = "left" }), hidden)
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }), hidden)
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "up" }), hidden)
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "down" }), hidden)
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ direction = "left" }), hidden)
hl.bind("SUPER + BracketRight", hl.dsp.focus({ direction = "right" }), hidden)

hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "l" }), hidden)
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "r" }), hidden)
hl.bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "u" }), hidden)
hl.bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "d" }), hidden)

hl.bind("ALT + F4", hl.dsp.window.close(), hidden)
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Forcefully zap a window" })
hl.bind("SUPER + W", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle float" })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Float/Tile" })
hl.bind("ALT + Return", hl.dsp.window.fullscreen(), { description = "Fullscreen" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Pin" })

-- Workspaces (keycodes 10–19 = keys 1–0; US Intl layout)
for i = 1, 10 do
    local code = 9 + i
    hl.bind("SUPER + code:" .. code, hl.dsp.focus({ workspace = i }), hidden)
    hl.bind("SUPER + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = i }), hidden)
    hl.bind("SUPER + ALT + code:" .. code, hl.dsp.window.move({ workspace = i, follow = false }), hidden)
end

-- Testing notifications
hl.bind(
    "SUPER + ALT + F11",
    hl.dsp.exec_cmd([=[bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | grep -v -i "nipple" | grep -v -i "pussy" | shuf -n 1); ACTION=$(notify-send "Test notification with body image" "This notification should contain your user account <b>image</b> and <a href=\"https://discord.com/app\">Discord</a> <b>icon</b>. Oh and here is a random image in your Pictures folder: <img src=\"$RANDOM_IMAGE\" alt=\"Testing image\"/>" -a "Hyprland keybind" -p -h "string:image-path:/var/lib/AccountsService/icons/$USER" -t 6000 -i "discord" -A "openImage=Profile image" -A "action2=Open the random image" -A "action3=Useless button"); [[ $ACTION == *openImage ]] && xdg-open "/var/lib/AccountsService/icons/$USER"; [[ $ACTION == *action2 ]] && xdg-open "$RANDOM_IMAGE"']=]),
    hidden
)
hl.bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd([=[bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | grep -v -i "nipple" | grep -v -i "pussy" | shuf -n 1); ACTION=$(notify-send "Test notification" "This notification should contain a random image in your <b>Pictures</b> folder and <a href=\"https://discord.com/app\">Discord</a> <b>icon</b>.\n<i>Flick right to dismiss!</i>" -a "Discord (fake)" -p -h "string:image-path:$RANDOM_IMAGE" -t 6000 -i "discord" -A "openImage=Profile image" -A "action2=Useless button"); [[ $ACTION == *openImage ]] && xdg-open "/var/lib/AccountsService/icons/$USER"']=]),
    hidden
)
hl.bind(
    "SUPER + ALT + Equal",
    hl.dsp.exec_cmd("notify-send \"Urgent notification\" \"Ah hell no\" -u critical -a 'Hyprland keybind'"),
    hidden
)

-- Session
hl.bind("SUPER + L", hl.dsp.global("donwaztok:lock"), { description = "Lock" })

-- Media
hl.bind(
    "SUPER + SHIFT + N",
    hl.dsp.exec_cmd("playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"),
    { locked = true, description = "Next track" }
)
hl.bind(
    "XF86AudioNext",
    hl.dsp.exec_cmd("playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"),
    { locked = true, description = "[hidden]" }
)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "[hidden]" })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"), { description = "[hidden]" })
hl.bind(
    "SUPER + SHIFT + ALT + mouse:276",
    hl.dsp.exec_cmd("playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"),
    { description = "[hidden]" }
)
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "[hidden]" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "[hidden]" })
hl.bind(
    "SUPER + R",
    hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/change-audio-output.sh"),
    { description = "Change audio output" }
)

-- Apps
hl.bind(
    "SUPER + Return",
    hl.dsp.exec_cmd(launchScript .. " " .. terminalApps),
    { description = "Terminal" }
)
hl.bind("SUPER + T", hl.dsp.exec_cmd(launchScript .. " " .. terminalApps), hidden)
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(launchScript .. " " .. terminalApps), hidden)
hl.bind(
    "SUPER + E",
    hl.dsp.exec_cmd(
        launchScript
            .. ' "nautilus" "nemo" "thunar" "${TERMINAL}" "kitty -1 zsh -c yazi"'
    ),
    { description = "File manager" }
)
hl.bind(
    "SUPER + F",
    hl.dsp.exec_cmd(
        launchScript
            .. ' "google-chrome-stable" "zen-browser" "firefox" "brave" "chromium" "microsoft-edge-stable" "opera" "librewolf"'
    ),
    { description = "Browser" }
)
hl.bind(
    "SUPER + C",
    hl.dsp.exec_cmd(
        launchScript
            .. ' "gtk-launch cursor" "antigravity" "code" "codium" "zed" "zedit" "zeditor" "kate" "gnome-text-editor" "emacs" "command -v nvim && kitty -1 nvim" "command -v micro && kitty -1 micro"'
    ),
    { description = "Code editor" }
)
hl.bind(
    "SUPER + X",
    hl.dsp.exec_cmd(launchScript .. ' "kate" "gnome-text-editor" "emacs"'),
    { description = "Text editor" }
)
hl.bind(
    "CTRL + SUPER + V",
    hl.dsp.exec_cmd(launchScript .. ' "pavucontrol-qt" "pavucontrol"'),
    { description = "Volume mixer" }
)
hl.bind("SUPER + I", hl.dsp.exec_cmd(qs("ipc call controlCenter open")), { description = "Donwaztok Control Center (Settings)" })
hl.bind(
    "CTRL + SHIFT + Escape",
    hl.dsp.exec_cmd(launchScript .. ' "gnome-system-monitor" "kitty -1 btop"'),
    { description = "Task manager" }
)
