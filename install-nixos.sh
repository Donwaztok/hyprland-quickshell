#!/usr/bin/env bash
# =============================================================================
# NixOS install — Donwaztok Hyprland + Quickshell
# Detects username/hostname, writes nix/local.nix, copies hardware, rebuilds.
#
# Usage:
#   ./install-nixos.sh              # generate configs + rebuild
#   ./install-nixos.sh --no-rebuild # only generate local.nix + hardware.nix
#   ./install-nixos.sh --force      # overwrite existing nix/local.nix
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOCAL_NIX="$REPO_ROOT/nix/local.nix"
HARDWARE_NIX="$REPO_ROOT/nix/hosts/desktop/hardware.nix"
HARDWARE_SRC="/etc/nixos/hardware-configuration.nix"

DO_REBUILD=1
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --no-rebuild) DO_REBUILD=0 ;;
    --force) FORCE=1 ;;
    -h | --help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $arg (use --help)"
      exit 1
      ;;
  esac
done

# --- helpers -----------------------------------------------------------------

info() { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[0;31m[ERR]\033[0m %s\n' "$*" >&2; }

sanitize_flake_host() {
  # Nix attribute names: letters, digits, _, -
  local raw="${1,,}" # lowercase
  raw="$(printf '%s' "$raw" | tr -c 'a-z0-9_ -' '_' | tr ' ' '_')"
  raw="${raw##_}"
  raw="${raw%%_}"
  printf '%s' "$raw"
}

# --- detect user / host ------------------------------------------------------

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  USERNAME="$SUDO_USER"
elif [[ "$(id -un)" == "root" && -z "${SUDO_USER:-}" ]]; then
  err "Não execute como root puro. Use um usuário com sudo:"
  err "  su - seuusuario"
  err "  cd ~/.config && ./install-nixos.sh"
  exit 1
else
  USERNAME="$(id -un)"
fi

HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
HOSTNAME="${HOSTNAME%%.*}"

FLAKE_HOST="$(sanitize_flake_host "$HOSTNAME")"
if [[ -z "$FLAKE_HOST" ]]; then
  FLAKE_HOST="$(sanitize_flake_host "$USERNAME")"
fi

if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
  err "flake.nix não encontrado em $REPO_ROOT"
  exit 1
fi

info "Usuário:    $USERNAME"
info "Hostname:   $HOSTNAME"
info "Flake host: $FLAKE_HOST  →  nixos-rebuild --flake path:$REPO_ROOT#$FLAKE_HOST"

# --- nix/local.nix -----------------------------------------------------------

mkdir -p "$(dirname "$LOCAL_NIX")"

if [[ -f "$LOCAL_NIX" && "$FORCE" -ne 1 ]]; then
  warn "nix/local.nix já existe. Use --force para sobrescrever."
else
  info "Gerando $LOCAL_NIX ..."
  cat >"$LOCAL_NIX" <<EOF
# Gerado por install-nixos.sh em $(date -Iseconds)
{
  username = "$USERNAME";
  hostname = "$HOSTNAME";
  flakeHost = "$FLAKE_HOST";
}
EOF
fi

# --- hardware.nix ------------------------------------------------------------

mkdir -p "$(dirname "$HARDWARE_NIX")"

if [[ -f "$HARDWARE_NIX" && "$FORCE" -ne 1 ]]; then
  warn "hardware.nix já existe — mantendo o atual."
elif [[ -f "$HARDWARE_SRC" ]]; then
  info "Copiando $HARDWARE_SRC → $HARDWARE_NIX"
  cp "$HARDWARE_SRC" "$HARDWARE_NIX"
else
  warn "hardware-configuration.nix não encontrado em /etc/nixos."
  warn "Copie manualmente após instalar o NixOS:"
  warn "  sudo cp /etc/nixos/hardware-configuration.nix $HARDWARE_NIX"
  if [[ ! -f "$HARDWARE_NIX" ]]; then
    warn "Usando hardware.example.nix como fallback no primeiro rebuild."
  fi
fi

# --- rebuild -----------------------------------------------------------------

if [[ "$DO_REBUILD" -eq 0 ]]; then
  info "Arquivos gerados. Rebuild omitido (--no-rebuild)."
  info "Quando estiver pronto:"
  info "  sudo nixos-rebuild switch --flake path:$REPO_ROOT#$FLAKE_HOST"
  exit 0
fi

if ! command -v nixos-rebuild >/dev/null 2>&1; then
  err "nixos-rebuild não encontrado. Este script é para NixOS."
  exit 1
fi

if [[ "$(id -un)" == "root" ]]; then
  err "Rebuild deve ser feito com sudo a partir do seu usuário, não como root login."
  exit 1
fi

info "Iniciando nixos-rebuild (pode demorar na primeira vez) ..."
# path: inclui nix/local.nix (gitignored) — flakes via git ignoram arquivos não rastreados
sudo nixos-rebuild switch --flake "path:$REPO_ROOT#$FLAKE_HOST" \
  --option extra-experimental-features 'nix-command flakes'

echo ""
info "Instalação concluída."
info "  Rebuild: sudo nixos-rebuild switch --flake path:$REPO_ROOT#$FLAKE_HOST"
info "  Atalho:  up   (após reiniciar sessão zsh)"
info "  Reinicie se for a primeira instalação gráfica: sudo reboot"
