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

  # VM / BIOS sem partição EFI: "/dev/vda". Desktop UEFI: null (usa systemd-boot).
  grubDevice = null;

  # RTX/GTX no hardware real (drivers proprietários + fbdev).
  nvidia = false;

  # VM / headless: não aplica layout DP-1 + HDMI-A-1 de monitors.lua.
  skipMonitorLayout = false;

  # Pacotes extras do nixos-unstable (não inclui Hyprland — use stable 26.05).
  useUnstablePackages = false;
}
