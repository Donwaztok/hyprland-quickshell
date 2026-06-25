# Pacotes do nixos-unstable sobre stable (resto do sistema fica em 26.05).
{ inputs, ... }:
{
  nixpkgs.overlays = [
    (final: prev:
      let
        u = inputs.unstable.legacyPackages.${prev.system};
      in
      {
        inherit (u)
          hyprland
          xdg-desktop-portal-hyprland
          hypridle
          hyprlock
          hyprpicker
          hyprshot
          quickshell
          ;
      })
  ];
}
