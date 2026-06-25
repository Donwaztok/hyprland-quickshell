{
  description = "Donwaztok — Hyprland + Quickshell (NixOS stable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      forAllSystems = nixpkgs.lib.genAttrs [ system ];

      # Cada pessoa copia nix/local.example.nix → nix/local.nix e edita.
      local =
        if builtins.pathExists ./nix/local.nix then
          import ./nix/local.nix
        else
          import ./nix/local.example.nix;
    in
    {
      nixosConfigurations.${local.flakeHost} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs local;
          dotfiles = self;
        };
        modules = [
          ./nix/hosts/desktop
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs local;
              dotfiles = self;
            };
            home-manager.users.${local.username} = import ./nix/home;
          }
        ];
      };

      formatter = forAllSystems (s: nixpkgs.legacyPackages.${s}.nixfmt-tree);
    };
}
