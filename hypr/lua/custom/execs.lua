-- Custom autostart (runs once per Hyprland session)

hl.on("hyprland.start", function()
    -- Tray: Bluetooth (network lives in the shell)
    hl.exec_cmd("blueman-applet")

    -- Apps
    -- hl.exec_cmd("gtk-launch vesktop")
    hl.exec_cmd("gtk-launch zen")
    hl.exec_cmd("gtk-launch com.rtosta.zapzap.nogpu")
    -- hl.exec_cmd("QT_QPA_PLATFORM=wayland __GLX_VENDOR_LIBRARY_NAME=mesa zapzap --disable-gpu")
    hl.exec_cmd("gtk-launch org.mozilla.Thunderbird")

    -- Put windows back where the saved layout has them (no saved layout: does nothing)
    hl.exec_cmd("~/.config/hypr/custom/scripts/window_layout.py restore --boot")
end)
