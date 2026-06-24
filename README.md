# Donwaztok — Hyprland + Quickshell

Dotfiles para **NixOS 25.11 stable**: Hyprland, Quickshell (`donwaztok`), Kitty, Fuzzel, Zsh, SDDM, barra M3.

Fork: [github.com/Donwaztok/hyprland-quickshell](https://github.com/Donwaztok/hyprland-quickshell) · branch **`nixos`**

> **Arch Linux:** branch `main` (com `install.sh`).

---

## Instalação

**Requisitos:** NixOS já instalado (mesmo sem interface), usuário com `sudo`, `git` e `curl`.

### One-liner (GitHub)

```bash
curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash
```

Clona em `~/.config`, detecta usuário/hostname, copia hardware e faz o rebuild.

```bash
# opções
curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash -s -- --no-rebuild
curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash -s -- --force
TARGET=~/dotfiles curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash
```

### Com git

```bash
git clone -b nixos https://github.com/Donwaztok/hyprland-quickshell.git ~/.config
~/.config/install-nixos.sh
sudo reboot
```

### Atualizar

```bash
sudo nixos-rebuild switch --flake ~/.config#<hostname>
# ou, no zsh: up
```

Mais detalhes (pacotes, flatpak, estrutura Nix): [`nix/README.md`](nix/README.md)

---

## Atalhos

| Atalho | Ação |
|--------|------|
| Super+/ | Lista de keybinds |
| Super+Enter | Terminal (Kitty) |

---

## Estrutura

```
~/.config/
├── flake.nix, install-nixos.sh, bootstrap.sh
├── nix/                    # módulos NixOS + Home Manager
├── hypr/                   # Hyprland
├── quickshell/donwaztok/   # bar, drawers, lock (qsConfig = donwaztok)
├── donwaztok/config.json   # tema M3 + apps
└── kitty/, fuzzel/, wlogout/, …
```

`donwaztok` é o nome do **shell Quickshell**, não do usuário Linux.

---

## Créditos

Baseado em [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (Illogical Impulse) e trechos de [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPLv3).
