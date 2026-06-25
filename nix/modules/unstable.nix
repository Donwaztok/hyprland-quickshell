# Overlay opcional do nixos-unstable.
#
# nixos-26.05 stable já traz Hyprland 0.55.3 e todo o ecossistema Hypr
# (hypridle, hyprlock, portal-hyprland, quickshell, …). NÃO substituir
# hyprland daqui — misturar unstable com libs stable quebra aquamarine
# ("system has unknown") e o compositor não sobe.
#
# Use `local.useUnstablePackages` em nix/local.nix para pacotes extras.
{ inputs, lib, local, ... }:
let
  useUnstable = local ? useUnstablePackages && local.useUnstablePackages;
in
{
  nixpkgs.overlays = lib.mkIf useUnstable [
    (final: prev:
      let
        u = inputs.unstable.legacyPackages.${prev.system};
      in
      {
        # Exemplo: inherit (u) somePackage;
      })
  ];
}
