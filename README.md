# Hyprland + Quickshell

Dotfiles for Hyprland, Quickshell, Fish, Kitty, Fuzzel, and related tools (inspired by [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)).

**Repository:** [github.com/Donwaztok/hyprland-quickshell](https://github.com/Donwaztok/hyprland-quickshell)

## Requirements

- **Arch Linux** (or derivative)
- AUR access (yay)

## Installation

Clone into `~/.config` and run the install script:

```bash
git clone https://github.com/Donwaztok/hyprland-quickshell.git ~/.config
cd ~/.config
chmod +x install.sh
./install.sh
```

The script runs **entirely locally** and:

1. **Pacman** – configures mirrors (BR/US), Color, multilib (first run only).
2. **Yay** – installs if missing.
3. **Packages** – installs everything listed in `app.lst` (via yay).
4. **Themes & appearance** – Bibata cursor, SDDM Candy, GTK Graphite, Tela icons, GRUB Particle-circle.
5. **Desktop files** – copies `hypr/source/*.desktop` to `~/.local/share/applications/`.
6. **Services** – enables sddm, NetworkManager, bluetooth, ydotool; adds user to groups (video, input, i2c).

## Structure

| Path | Description |
|------|-------------|
| `hypr/` | Hyprland configs, scripts, hyprlock, hypridle. `hypr/source/`: SDDM Candy tarball, desktop files. |
| `quickshell/ii/` | Quickshell bar and widgets. |
| `fish/` | Fish shell. |
| `kitty/`, `foot/` | Terminals. |
| `fuzzel/` | Launcher. |
| `wlogout/` | Logout menu. |
| `fontconfig/`, `matugen/` | Fonts and Material colors. |
| `starship.toml` | Fish prompt. |
| `kdeglobals`, `Kvantum/`, `kde-material-you-colors/` | KDE/Qt theme. |
| `app.lst` | Package list used by `install.sh`. |
| `install.sh` | Single install script. |

## After installation

- **Super+/** – keybind list.
- **Super+Enter** – terminal (Kitty).
- Configs live in `~/.config`; edit and version as you like.

## app.lst

Flat list of packages (Arch + AUR). `install.sh` installs them with:

```bash
yay --removemake --cleanafter -S $(awk '!/^#/ {print $1}' app.lst)
```

At minimum you need `quickshell-git` (AUR) for the bar. Add or install any other packages (e.g. MicroTeX, custom Bibata) as needed.
