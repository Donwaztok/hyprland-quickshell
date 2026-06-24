# Copie para local.nix e ajuste para a sua máquina:
#   cp nix/local.example.nix nix/local.nix
#
# local.nix não vai para o git (cada pessoa tem o seu).

{
  # Nome de login no sistema (whoami)
  username = "don";

  # Nome da máquina na rede (hostname)
  hostname = "don";

  # Nome usado no flake: nixos-rebuild switch --flake ~/.config#<flakeHost>
  flakeHost = "don";
}
