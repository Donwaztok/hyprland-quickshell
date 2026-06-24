#!/usr/bin/env bash
# =============================================================================
# Bootstrap — clone do GitHub + install-nixos.sh
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/Donwaztok/hyprland-quickshell/nixos/bootstrap.sh | bash
#
# Ou, se já tiver git:
#   git clone -b nixos https://github.com/Donwaztok/hyprland-quickshell.git ~/.config \
#     && ~/.config/install-nixos.sh
# =============================================================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Donwaztok/hyprland-quickshell.git}"
BRANCH="${BRANCH:-nixos}"
TARGET="${TARGET:-$HOME/.config}"

info() { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[0;31m[ERR]\033[0m %s\n' "$*" >&2; }

if [[ "$(id -un)" == "root" && -z "${SUDO_USER:-}" ]]; then
  err "Não rode como root. Entre com seu usuário normal (com sudo)."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  err "git não encontrado. No NixOS mínimo: nix-shell -p git --run 'bash -s' <(curl -fsSL .../bootstrap.sh)"
  exit 1
fi

if [[ -e "$TARGET/.git" ]]; then
  warn "$TARGET já é um repositório git."
  if [[ -f "$TARGET/install-nixos.sh" ]]; then
    info "Executando install-nixos.sh existente ..."
    exec "$TARGET/install-nixos.sh" "$@"
  fi
  err "Remova ou renomeie $TARGET antes de clonar de novo."
  exit 1
fi

if [[ -e "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  err "$TARGET existe e não está vazio."
  err "Mova ou apague o conteúdo, ou defina outro destino: TARGET=~/dotfiles bash"
  exit 1
fi

info "Clonando $REPO_URL (branch $BRANCH) → $TARGET"
git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TARGET"

info "Iniciando instalação ..."
exec "$TARGET/install-nixos.sh" "$@"
