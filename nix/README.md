# NixOS

Flake + Home Manager para NixOS 25.11 stable.

## Instalação

Prefira o one-liner (ver [README](../README.md)):

```bash
curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash
```

Ou:

```bash
git clone -b nixos https://github.com/Donwaztok/hyprland-quickshell.git ~/.config
~/.config/install-nixos.sh
```

Os scripts geram `nix/local.nix` (usuário + hostname) e copiam `hardware-configuration.nix`.

## Config local (por máquina)

| Arquivo | Git | Conteúdo |
|---------|-----|----------|
| `nix/local.nix` | não | username, hostname, flakeHost |
| `nix/hosts/desktop/hardware.nix` | não | discos, bootloader, drivers |

Gerados automaticamente pelo `install-nixos.sh`. Para editar manualmente, copie `nix/local.example.nix`.

## Atualizar

```bash
sudo nixos-rebuild switch --flake ~/.config#<flakeHost>
# zsh: up
```

## Pós-instalação (Flatpak)

```bash
flatpak install flathub com.rtosta.zapzap
flatpak install flathub app.zen_browser.zen
```

## Onde mudar o quê

| Quer mudar… | Arquivo |
|-------------|---------|
| Pacotes | `nix/modules/packages.nix` |
| Hyprland / portals | `nix/modules/hyprland.nix` |
| Dotfiles (hypr, qs…) | pastas na raiz → deploy em `nix/home/dotfiles.nix` |
| Cursor | `code-cursor` em `nix/modules/cursor.nix` (unfree) |

## Estrutura `nix/`

```
nix/
├── local.nix              # gerado — username, hostname, flakeHost
├── hosts/desktop/         # host + hardware.nix
├── modules/               # sistema, pacotes, hyprland, cursor
└── home/                  # Home Manager (zsh, gtk, dotfiles)
```
