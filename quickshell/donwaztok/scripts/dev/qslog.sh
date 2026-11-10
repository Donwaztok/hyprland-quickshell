#!/bin/sh
# Shell log since a mark, for checking an edit:  qslog.sh mark; <edit, wait for the reload>; qslog.sh new
# Drops the qt.qpa.wayland.textinput noise. The mark lives in $XDG_RUNTIME_DIR.
mark="${XDG_RUNTIME_DIR:-/tmp}/donwaztok-qslog.mark"
log() { timeout 5 qs log -c donwaztok 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'; }
case "$1" in
mark) log | wc -l > "$mark" ;;
new) log | tail -n +"$(( $(cat "$mark" 2>/dev/null || echo 0) + 1 ))" | grep -v "qt.qpa.wayland.textinput" ;;
*) echo "usage: $0 mark|new" >&2; exit 2 ;;
esac
