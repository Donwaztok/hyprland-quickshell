#!/bin/sh
# Focus a window by title prefix before sending keys:  focus.sh "min.json" && wtype ...
# Focus follows the mouse here, so the cursor is parked on the window too; exits 1 unless it ends up active.
# Prints "x y w h" of the window.
[ -n "$1" ] || { echo "usage: $0 <title prefix>" >&2; exit 2; }
read -r addr x y w h <<EOT
$(hyprctl clients -j | python3 -c '
import json, sys
c = next((c for c in json.load(sys.stdin) if c["title"].startswith(sys.argv[1])), None)
print(*(c and [c["address"], *c["at"], *c["size"]] or [""]))' "$1")
EOT
[ -n "$addr" ] || { echo "no window titled $1*" >&2; exit 1; }
hyprctl dispatch "hl.dsp.focus({ window = [[address:$addr]] })" >/dev/null
sleep 0.4
# ydotool absolute coordinates are half the global ones on this setup (see CLAUDE.md).
ydotool mousemove --absolute -x $(( (x + w / 2) / 2 )) -y $(( (y + h / 2) / 2 )) >/dev/null 2>&1
sleep 0.4
active=$(hyprctl activewindow -j | python3 -c 'import json, sys; print(json.load(sys.stdin).get("address", ""))')
[ "$active" = "$addr" ] || { echo "focus did not stick on $1" >&2; exit 1; }
echo "$x $y $w $h"
