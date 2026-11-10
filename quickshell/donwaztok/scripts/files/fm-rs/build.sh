#!/usr/bin/env bash
# Build the Donwaztok Rust helpers → quickshell/donwaztok/bin/
# (fm, plus the donwaztok-portal and donwaztok-bt-agent daemons from daemons/)
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
  cargo build --release --workspace
)
# Prefer crate-local target; fall back to CARGO_TARGET_DIR
OUT="$SRC/target/release"
if [ ! -x "$OUT/fm" ] && [ -n "${CARGO_TARGET_DIR:-}" ]; then
  OUT="$CARGO_TARGET_DIR/release"
fi
for bin in fm donwaztok-portal donwaztok-bt-agent; do
  if [ ! -x "$OUT/$bin" ]; then
    echo "[fm] Build succeeded but binary not found at $OUT/$bin" >&2
    exit 1
  fi
  # Replace by rename: the running portal/agent keep their old inode instead of crashing.
  cp -f "$OUT/$bin" "$BIN_DIR/.$bin.new"
  chmod +x "$BIN_DIR/.$bin.new"
  mv -f "$BIN_DIR/.$bin.new" "$BIN_DIR/$bin"
  echo "[fm] Installed → $BIN_DIR/$bin"
done
