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
    ../../modules/unstable.nix
    ../../modules/graphics.nix
    ../../modules/system.nix
    ../../modules/hyprland.nix
    ../../modules/packages.nix
    ../../modules/cursor.nix
    ../../modules/flatpak.nix
    (if builtins.pathExists ./hardware.nix then ./hardware.nix else ./hardware.example.nix)
  ];

  networking.hostName = local.hostname;
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  users.users.${local.username} = {
    isNormalUser = true;
    description = local.username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "i2c"
    ];
    shell = pkgs.zsh;
  };

  environment.sessionVariables = {
    DONWAZTOK_CONFIG_ROOT = "${dotfiles}";
  }
  // lib.optionalAttrs (local ? skipMonitorLayout && local.skipMonitorLayout) {
    DONWAZTOK_SKIP_MONITOR_LAYOUT = "1";
  };

  system.stateVersion = "25.11";
}
