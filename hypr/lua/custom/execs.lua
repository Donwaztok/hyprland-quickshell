-- Custom autostart (runs once per Hyprland session)

hl.on("hyprland.start", function()
    -- Tray: Bluetooth (network lives in the shell)
    hl.exec_cmd("blueman-applet")

    -- Apps
    -- hl.exec_cmd("gtk-launch vesktop")
    hl.exec_cmd("gtk-launch zen")
    -- WhatsApp as a Zen web app; waits so Zen is up and the second launch reuses its process
    hl.exec_cmd("sleep 3; gtk-launch zen.webapp-eb053312-1790-456f-be26-fae75391f1a0")
    hl.exec_cmd("gtk-launch org.mozilla.Thunderbird")

    -- Put windows back where the saved layout has them (no saved layout: does nothing)
    hl.exec_cmd("~/.config/hypr/custom/scripts/window_layout.py restore --boot")
end)
