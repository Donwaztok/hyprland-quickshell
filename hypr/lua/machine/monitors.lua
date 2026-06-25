-- Monitor layout (edit manually or regenerate from nwg-displays)
-- Set DONWAZTOK_SKIP_MONITOR_LAYOUT=1 on VMs without DP-1 / HDMI-A-1.

if os.getenv("DONWAZTOK_SKIP_MONITOR_LAYOUT") == "1" then
    return
end

hl.monitor({
    output = "DP-1",
    mode = "1920x1080@239.76",
    position = "0x0",
    scale = 1.0,
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1080@60.0",
    position = "1920x0",
    scale = 1.0,
})

-- hl.monitor({
--     output = "HDMI-A-1",
--     mode = "2560x1440@60.0",
--     position = "1920x0",
--     scale = 1.0,
-- })
