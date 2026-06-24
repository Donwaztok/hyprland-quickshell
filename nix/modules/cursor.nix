{ config, pkgs, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # Cursor 3.8.x from official AppImage (see nix/packages/cursor.nix).
  environment.systemPackages = [
    pkgs.callPackage ../packages/cursor.nix { }
  ];
}
