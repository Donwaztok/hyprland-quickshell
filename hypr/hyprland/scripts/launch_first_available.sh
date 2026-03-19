#!/usr/bin/env bash
source ~/.zshrc
for cmd in "$@"; do
 [[ -z "$cmd" ]] && continue
 eval "command -v ${cmd%% *}" >/dev/null 2>&1 || continue
 eval "$cmd" &
 exit
done
