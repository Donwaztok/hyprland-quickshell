-- Custom autostart (runs once per Hyprland session)

hl.on("hyprland.start", function()
    -- exec-once = fcitx5

    -- Tray: NetworkManager + Bluetooth
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")

    -- Peripherals
    hl.exec_cmd("solaar -w hide -b symbolic")

    -- Apps
    -- hl.exec_cmd("gtk-launch vesktop")
    hl.exec_cmd("gtk-launch zen")
    hl.exec_cmd("gtk-launch com.rtosta.zapzap")
    -- hl.exec_cmd("QT_QPA_PLATFORM=wayland __GLX_VENDOR_LIBRARY_NAME=mesa zapzap --disable-gpu")
    hl.exec_cmd("gtk-launch org.mozilla.Thunderbird")
end)
