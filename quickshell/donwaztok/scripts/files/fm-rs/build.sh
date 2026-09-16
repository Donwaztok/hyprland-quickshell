#!/usr/bin/env bash
# Build Donwaztok fm helper (Rust) → quickshell/donwaztok/bin/fm
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$ROOT/bin"
mkdir -p "$BIN_DIR"

if ! command -v cargo >/dev/null 2>&1; then
  echo "[fm] cargo not found — install rust (pacman -S rust) and re-run." >&2
  exit 1
fi

echo "[fm] Building release…"
(
  cd "$SRC"
  cargo build --release
)
# Prefer crate-local target; fall back to CARGO_TARGET_DIR
SRC_BIN="$SRC/target/release/fm"
if [ ! -x "$SRC_BIN" ] && [ -n "${CARGO_TARGET_DIR:-}" ]; then
  SRC_BIN="$CARGO_TARGET_DIR/release/fm"
fi
if [ ! -x "$SRC_BIN" ]; then
  echo "[fm] Build succeeded but binary not found at $SRC_BIN" >&2
  exit 1
fi
cp -f "$SRC_BIN" "$BIN_DIR/fm"
chmod +x "$BIN_DIR/fm"
echo "[fm] Installed → $BIN_DIR/fm"
