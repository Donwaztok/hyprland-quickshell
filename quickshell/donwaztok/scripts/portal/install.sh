#!/usr/bin/env bash
# Install Donwaztok FileChooser portal into user dirs and prefer it over GTK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"
PORTAL_DIR="${HOME_DIR}/.local/share/xdg-desktop-portal/portals"
DBUS_DIR="${HOME_DIR}/.local/share/dbus-1/services"
SYSTEMD_DIR="${HOME_DIR}/.config/systemd/user"
XDG_PORTAL_CFG="${HOME_DIR}/.config/xdg-desktop-portal"

mkdir -p "$PORTAL_DIR" "$DBUS_DIR" "$SYSTEMD_DIR" "$XDG_PORTAL_CFG"

chmod +x "$ROOT/xdg-desktop-portal-donwaztok.py"
cp -f "$ROOT/donwaztok.portal" "$PORTAL_DIR/donwaztok.portal"
cp -f "$ROOT/xdg-desktop-portal-donwaztok.service" "$SYSTEMD_DIR/xdg-desktop-portal-donwaztok.service"

sed "s|@HOME@|${HOME_DIR}|g" \
  "$ROOT/org.freedesktop.impl.portal.desktop.donwaztok.service.in" \
  > "$DBUS_DIR/org.freedesktop.impl.portal.desktop.donwaztok.service"

# Prefer Donwaztok for FileChooser; keep Hyprland/GTK for the rest.
cat > "$XDG_PORTAL_CFG/hyprland-portals.conf" <<'EOF'
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = donwaztok;gtk
EOF

# Also write portals.conf (xdg-desktop-portal >= 1.18)
cat > "$XDG_PORTAL_CFG/portals.conf" <<'EOF'
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = donwaztok;gtk
EOF

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now xdg-desktop-portal-donwaztok.service 2>/dev/null || true
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
systemctl --user restart xdg-desktop-portal-donwaztok.service 2>/dev/null || true

echo "[portal] Donwaztok FileChooser installed."
echo "  portal: $PORTAL_DIR/donwaztok.portal"
echo "  service: xdg-desktop-portal-donwaztok.service"
echo "  preferred: FileChooser = donwaztok;gtk"
