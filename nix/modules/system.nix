{
  config,
  lib,
  pkgs,
  dotfiles,
  local,
  ...
}:
let
  useGrub = local ? grubDevice && local.grubDevice != null;
in
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    substituters = [ "https://cache.nixos.org" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrOdR04oFzG4x5BUuzebCzc6="
    ];
  }
  // lib.optionalAttrs (local ? minimalInstall && local.minimalInstall) {
    # VM / disco pequeno: builds em disco (não tmpfs /build) e menos jobs paralelos.
    build-dir = "/var/tmp/nix-build";
    max-jobs = 2;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  boot.loader.systemd-boot.enable = lib.mkDefault (!useGrub);
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault (!useGrub);
  boot.loader.grub.enable = lib.mkDefault useGrub;
  boot.loader.grub.device = lib.mkIf useGrub local.grubDevice;

  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  security.polkit.enable = true;

  services.upower.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "Candy";
  };

  environment.systemPackages = [
    pkgs.kitty
  ];

  environment.etc."sddm/themes/Candy".source = "${dotfiles}/hypr/source/sddm-theme-candy";

  fonts.packages = with pkgs; [
    cascadia-code
    nerd-fonts.jetbrains-mono
    twemoji-color-font
    noto-fonts
    noto-fonts-color-emoji
    google-fonts
  ];

  fonts.fontconfig.enable = true;

  programs.zsh.enable = true;

  boot.kernelModules = [ "uinput" ];
  services.udev.packages = [ pkgs.ydotool ];
}
