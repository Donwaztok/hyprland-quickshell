{ config, pkgs, ... }:
{
  # Stable packages mapped from app.lst (Arch → nixpkgs 25.11)
  environment.systemPackages = with pkgs; [
    # Audio
    libdbusmenu-gtk3
    pavucontrol
    playerctl

    # Backlight / display
    brightnessctl
    ddcutil

    # Basic
    bc
    cliphist
    cmake
    curl
    yq-go
    jq
    ripgrep
    rsync
    wget
    xdg-user-dirs

    # Hyprland ecosystem
    wl-clipboard
    udiskie
    xorg.setxkbmap
    libayatana-appindicator
    networkmanagerapplet

    # GNOME / system utilities
    gnome-keyring
    gnome-control-center
    gnome-system-monitor
    polkit_gnome
    qt6.qt5compat

    # Build / Python
    clang
    gobject-introspection
    libsoup_3
    uv

    # Screenshot / capture
    hyprshot
    slurp
    swappy
    tesseract
    wf-recorder

    # Toolkit
    wtype
    ydotool

    # Widgets / launcher
    fuzzel
    hypridle
    hyprlock
    hyprpicker
    imagemagick
    libqalculate
    quickshell
    wlogout

    # Applications
    eog
    nautilus
    solaar
    thunderbird
    # zen-browser: install via Flatpak on stable if not in nixpkgs yet
    #   flatpak install flathub app.zen_browser.zen

    # Shell
    eza
    fastfetch
    starship
  ];
}
