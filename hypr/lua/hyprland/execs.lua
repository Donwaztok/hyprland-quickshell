local qs = require("lua.constants").qsCmd

hl.on("hyprland.start", function()
    -- Bar, wallpaper
    hl.exec_cmd(qs("&"))
    hl.exec_cmd("~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Core components
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Tray
    hl.exec_cmd("udiskie --no-automount --smart-tray --menu-update-workaround")

    -- Clipboard
    hl.exec_cmd("cliphist wipe")
    hl.exec_cmd(
        "wl-paste --type text --watch bash -c 'cliphist store && "
            .. qs("ipc call cliphistService update")
            .. "'"
    )
    hl.exec_cmd(
        "wl-paste --type image --watch bash -c 'cliphist store && "
            .. qs("ipc call cliphistService update")
            .. "'"
    )

    -- Keyboard: US International for XWayland
    hl.exec_cmd("setxkbmap -layout us -variant intl")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
