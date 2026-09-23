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
-- xdgdesktopportal → Qt QFileDialog uses xdg-desktop-portal → Donwaztok Files.
-- gtk3 forces the GTK chooser and bypasses our FileChooser portal.
hl.env("QT_QPA_PLATFORMTHEME", "xdgdesktopportal")
hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")
-- Quiet MPRIS Position warnings when Firefox/Chromium buses disappear mid-update
hl.env("QT_LOGGING_RULES", "quickshell.dbus.properties.warning=false")
hl.env("XDG_MENU_PREFIX", "gnome-")
-- Route GTK file dialogs through xdg-desktop-portal (Donwaztok FileChooser)
hl.env("GTK_USE_PORTAL", "1")

-- Virtual environment
hl.env("DONWAZTOK_VIRTUAL_ENV", os.getenv("HOME") .. "/.local/state/quickshell/.venv")

-- Terminal
hl.env("TERMINAL", "kitty -1")
