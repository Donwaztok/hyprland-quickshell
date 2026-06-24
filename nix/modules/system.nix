{
  config,
  lib,
  pkgs,
  dotfiles,
  ...
}:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = true;

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
