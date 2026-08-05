-- Environment variables

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Quickshell: QML imports
hl.env("QML2_IMPORT_PATH", os.getenv("HOME") .. "/.config/quickshell/donwaztok")

-- Applications
hl.env(
    "XDG_DATA_DIRS",
    os.getenv("HOME")
        .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
)

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")
hl.env("XDG_MENU_PREFIX", "gnome-")

-- Virtual environment
hl.env("DONWAZTOK_VIRTUAL_ENV", os.getenv("HOME") .. "/.local/state/quickshell/.venv")

-- Terminal
hl.env("TERMINAL", "kitty -1")
