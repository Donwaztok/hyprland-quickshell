{ config, pkgs, lib, local, ... }:
let
  minimal = local ? minimalInstall && local.minimalInstall;
in
{
  # Stable packages mapped from app.lst (Arch → nixpkgs 26.05)
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
    curl
    yq-go
    jq
    ripgrep
    rsync
    wget
    xdg-user-dirs

    # Hyprland ecosystem (0.55.3+ no nixos-26.05 stable)
    wl-clipboard
    udiskie
    setxkbmap
    libayatana-appindicator
    networkmanagerapplet

    # GNOME / system utilities
    gnome-keyring
    gnome-control-center
    gnome-system-monitor
    polkit_gnome
    qt6.qt5compat

    # Screenshot / capture
    hyprshot
    slurp
    swappy

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

    # Shell
    eza
    fastfetch
    starship
  ]
  ++ lib.optionals (!minimal) [
    # Pesados — omitidos em minimalInstall (VM / disco pequeno)
    google-fonts
    thunderbird
    wf-recorder
    tesseract
    cmake
    clang
    gobject-introspection
    libsoup_3
    uv
  ];
}
