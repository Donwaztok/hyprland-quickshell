#!/usr/bin/env bash
# Store a clipboard image in cliphist unless its pixels match the last stored image.
# ZapZap re-encodes every clipboard image when its window gains focus (a WhatsApp Web paste
# workaround); the bytes change, so cliphist's own dedup misses it and each screenshot shows twice.
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
cat >"$tmp"
last="${XDG_RUNTIME_DIR:-/tmp}/cliphist-last-image-signature"
sig=$(magick identify -format '%#' "$tmp" 2>/dev/null)
if [ -n "$sig" ] && [ "$sig" = "$(cat "$last" 2>/dev/null)" ]; then
    exit 0
fi
printf '%s' "$sig" >"$last"
cliphist store <"$tmp"
