#!/usr/bin/env bash
# =============================================================================
# Install script – https://github.com/Donwaztok/hyprland-quickshell
# Instala pacotes (app.lst), temas (SDDM, GRUB, GTK/ícones), serviços e setup.
#
# Uso: ./install.sh
# =============================================================================

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# 1. Pacman
# -----------------------------------------------------------------------------
if [ -f /etc/pacman.conf ] && [ ! -f /etc/pacman.conf.t2.bkp ]; then
  echo -e "\033[0;32m[PACMAN]\033[0m Configurando pacman..."
  sudo cp /etc/pacman.conf /etc/pacman.conf.t2.bkp
  sudo sed -i "/^#Color/c\Color\nILoveCandy/" /etc/pacman.conf
  sudo sed -i "/^#VerbosePkgLists/c\VerbosePkgLists/" /etc/pacman.conf
  sudo sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5/" /etc/pacman.conf
  sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
  sudo pacman -Sy
  if command -v reflector &>/dev/null; then
    sudo reflector --country Brazil,United_States --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  else
    sudo pacman -S --noconfirm reflector
    sudo reflector --country Brazil,United_States --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Rns --noconfirm reflector
  fi
  sudo pacman -Syyu --noconfirm
  sudo pacman -Fy
else
  echo -e "\033[0;33m[SKIP]\033[0m Pacman já configurado."
fi

# -----------------------------------------------------------------------------
# 2. Yay (AUR)
# -----------------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
  echo -e "\033[0;32m[YAY]\033[0m Instalando yay..."
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay
  ( cd /tmp/buildyay && makepkg -si --noconfirm )
  rm -rf /tmp/buildyay
else
  echo -e "\033[0;33m[SKIP]\033[0m yay já instalado."
fi

# -----------------------------------------------------------------------------
# 3. Pacotes (app.lst)
# -----------------------------------------------------------------------------
echo -e "\033[0;32m[PACOTES]\033[0m Instalando app.lst..."
if [ -f "$REPO_ROOT/app.lst" ]; then
  yay --removemake --cleanafter -S $(awk '!/^#/ {print $1}' "$REPO_ROOT/app.lst") || true
else
  echo -e "\033[0;33m[SKIP]\033[0m app.lst não encontrado."
fi

# -----------------------------------------------------------------------------
# 4. Temas e aparência (cursor, SDDM, GTK, ícones, GRUB)
# -----------------------------------------------------------------------------
mkdir -p "$HOME/.icons/default"
if ! grep -q 'Xcursor.theme' "$HOME/.Xresources" 2>/dev/null; then
  echo "Xcursor.theme: Bibata-Modern-Classic" >> "$HOME/.Xresources"
  echo "Xcursor.size: 20" >> "$HOME/.Xresources"
fi
if [ ! -f "$HOME/.icons/default/index.theme" ]; then
  echo "[Icon Theme]" > "$HOME/.icons/default/index.theme"
  echo "Inherits=Bibata-Modern-Classic" >> "$HOME/.icons/default/index.theme"
fi

if [ -f "$REPO_ROOT/hypr/source/Sddm_Candy.tar.gz" ]; then
  echo -e "\033[0;32m[SDDM]\033[0m Instalando tema Candy..."
  sudo mkdir -p /usr/share/sddm/themes
  sudo tar -xzf "$REPO_ROOT/hypr/source/Sddm_Candy.tar.gz" -C /usr/share/sddm/themes/
  sudo mkdir -p /etc/sddm.conf.d
  if [ -f /usr/share/sddm/themes/Candy/kde_settings.conf ]; then
    sudo cp /usr/share/sddm/themes/Candy/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf
  fi
fi

if [ ! -d /usr/share/themes/Graphite-Dark ]; then
  ( git clone --depth 1 https://github.com/vinceliuice/Graphite-gtk-theme /tmp/Graphite-gtk-theme
    cd /tmp/Graphite-gtk-theme
    ./install.sh -c dark -t yellow -l --tweaks normal rimless -s compact
    cd - >/dev/null
    rm -rf /tmp/Graphite-gtk-theme
  ) || true
fi

if [ ! -d /usr/share/icons/Tela-black ]; then
  ( git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme /tmp/Tela-icon-theme
    cd /tmp/Tela-icon-theme
    ./install.sh black
    cd - >/dev/null
    rm -rf /tmp/Tela-icon-theme
  ) || true
fi

if [ ! -d /boot/grub/themes/Particle-circle ] 2>/dev/null; then
  ( git clone --depth 1 https://github.com/yeyushengfan258/Particle-circle-grub-theme /tmp/Particle-circle-grub-theme
    cd /tmp/Particle-circle-grub-theme
    sudo ./install.sh -t window
    cd - >/dev/null
    rm -rf /tmp/Particle-circle-grub-theme
  ) || true
fi

# -----------------------------------------------------------------------------
# 5. Desktop files (launchers customizados)
# -----------------------------------------------------------------------------
mkdir -p "$HOME/.local/share/applications"
for f in "$REPO_ROOT/hypr/source/"*.desktop; do
  [ -f "$f" ] && cp -f "$f" "$HOME/.local/share/applications/"
done

# -----------------------------------------------------------------------------
# 6. Grupos de usuário e serviços (backlight, ydotool, bluetooth)
# -----------------------------------------------------------------------------
if command -v systemctl &>/dev/null; then
  if ! getent group i2c &>/dev/null; then
    sudo groupadd i2c 2>/dev/null || true
  fi
  sudo usermod -aG video,input,i2c "$(whoami)" 2>/dev/null || true

  [ -f /etc/modules-load.d/i2c-dev.conf ] || echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf &>/dev/null || true

  if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
    sudo systemctl --machine="$(whoami)@.host" --user enable ydotool --now 2>/dev/null || true
  else
    systemctl --user enable ydotool --now 2>/dev/null || true
  fi
  sudo systemctl enable bluetooth --now 2>/dev/null || true
  sudo systemctl enable sddm 2>/dev/null || true
  sudo systemctl enable NetworkManager 2>/dev/null || true
fi

echo ""
echo -e "\033[0;32m[OK]\033[0m Instalação concluída."
echo "  - Repo: https://github.com/Donwaztok/hyprland-quickshell"
echo "  - Configs: ~/.config (hypr, quickshell, fish, etc.)"
echo "  - Super+/ = keybinds, Super+Enter = terminal"
echo "  - SDDM/GRUB/GTK/ícones aplicados"
