{
  config,
  lib,
  pkgs,
  dotfiles,
  local,
  ...
}:
{
  imports = [
    ./dotfiles.nix
    ./zsh.nix
    ./gtk.nix
    ./services.nix
    ./packages.nix
  ];

  home.username = local.username;
  home.homeDirectory = "/home/${local.username}";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    QML2_IMPORT_PATH = "${config.home.homeDirectory}/.config/quickshell/donwaztok";
    DONWAZTOK_VIRTUAL_ENV = "${config.home.homeDirectory}/.local/state/quickshell/.venv";
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "gtk3";
    XDG_MENU_PREFIX = "gnome-";
    TERMINAL = "kitty -1";
  };

  xdg.enable = true;

  programs.starship.enable = true;
}
