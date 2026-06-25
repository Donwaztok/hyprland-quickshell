# GPU / Mesa — necessário para Hyprland 0.55+ iniciar (aquamarine/wlroots).
{ config, lib, local, ... }:
let
  useNvidia = local ? nvidia && local.nvidia;
in
{
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  services.xserver.videoDrivers = lib.mkIf useNvidia [ "nvidia" ];

  hardware.nvidia = lib.mkIf useNvidia {
    open = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;
    modesetting.enable = true;
  };

  boot.kernelParams = lib.mkIf useNvidia [ "nvidia-drm.fbdev=1" ];

  environment.sessionVariables = lib.mkIf useNvidia {
    NVD_BACKEND = "direct";
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
