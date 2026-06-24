{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # Cursor: official AppImage via code-cursor-nix (updates ~3x/week).
  # https://github.com/jacopone/code-cursor-nix
  environment.systemPackages = [
    inputs.code-cursor-nix.packages.${pkgs.system}.cursor
  ];
}
