#!/bin/bash

set -u

CREATIVE_MATCH="Creative_Stage_SE|Creative Stage SE"
CREATIVE_CARD_MATCH="alsa_card.usb-Creative_Technology_Ltd_Creative_Stage_SE"
CREATIVE_PROFILE="output:analog-stereo"
CREATIVE_VOLUME="60%"
CREATIVE_LABEL="Creative Stage SE"

HYPERX_MATCH="HyperX_Cloud_Stinger|HyperX Cloud Stinger"
HYPERX_CARD_MATCH="alsa_card.usb-Kingston_HyperX_Cloud_Stinger"
HYPERX_PROFILE="output:analog-stereo+input:analog-mono"
HYPERX_VOLUME="90%"
HYPERX_LABEL="HyperX Cloud Stinger Core Wireless + 7.1"

notify() {
    notify-send "$@" >/dev/null 2>&1 || true
}

card_name_by_match() {
    timeout 3 pactl list cards 2>/dev/null | awk -v pat="$1" '
        $1 == "Name:" && $2 ~ pat {
            print $2
            exit
        }
    '
}

card_active_profile() {
    local card="$1"
    timeout 3 pactl list cards 2>/dev/null | awk -v card="$card" '
        $1 == "Name:" && $2 == card { found = 1 }
        found && /Active Profile:/ {
            print $3
            exit
        }
    '
}

ensure_card_profile() {
    local card="$1"
    local profile="$2"
    [[ -n "$card" && -n "$profile" ]] || return 1
    local active
    active="$(card_active_profile "$card")"
    if [[ "$active" == "$profile" ]]; then
        return 0
    fi
    if [[ "$active" == "off" && "$profile" != "off" && "$profile" != "pro-audio" ]]; then
        timeout 3 pactl set-card-profile "$card" pro-audio >/dev/null 2>&1 || true
        sleep 0.45
    fi
    timeout 3 pactl set-card-profile "$card" "$profile" >/dev/null 2>&1 || true
}

sink_name_by_match() {
    timeout 3 pactl list short sinks 2>/dev/null | awk -v pat="$1" '$2 ~ pat { print $2; exit }'
}

wp_sink_id_by_match() {
    timeout 3 wpctl status 2>/dev/null | awk -v pat="$1" '
        /Sinks:/ { flag = 1; next }
        /Sources:/ { flag = 0 }
        flag && $0 ~ pat {
            if (match($0, /[0-9]+\./)) {
                print substr($0, RSTART, RLENGTH - 1)
                exit
            }
        }
    '
}

move_streams() {
    local sink="$1"
    local id
    while read -r id; do
        [[ -n "$id" ]] || continue
        timeout 3 pactl move-sink-input "$id" "$sink" >/dev/null 2>&1 || true
    done < <(timeout 3 pactl list short sink-inputs 2>/dev/null | awk '{ print $1 }')
}

CREATIVE_CARD="$(card_name_by_match "$CREATIVE_CARD_MATCH")"
HYPERX_CARD="$(card_name_by_match "$HYPERX_CARD_MATCH")"

if [[ -z "$(sink_name_by_match "$CREATIVE_MATCH")" ]]; then
    ensure_card_profile "$CREATIVE_CARD" "$CREATIVE_PROFILE"
    sleep 0.4
fi
if [[ -z "$(sink_name_by_match "$HYPERX_MATCH")" ]]; then
    ensure_card_profile "$HYPERX_CARD" "$HYPERX_PROFILE"
    sleep 0.4
fi

CREATIVE_SINK="$(sink_name_by_match "$CREATIVE_MATCH")"
HYPERX_SINK="$(sink_name_by_match "$HYPERX_MATCH")"

if [[ -z "$CREATIVE_SINK" || -z "$HYPERX_SINK" ]]; then
    notify "Audio" "Could not find Creative Stage SE or HyperX output"
    exit 1
fi

CURRENT="$(timeout 3 pactl get-default-sink 2>/dev/null || true)"

if [[ "$CURRENT" == "$CREATIVE_SINK" ]]; then
    NEW_SINK="$HYPERX_SINK"
    NEW_NAME="$HYPERX_LABEL"
    NEW_VOLUME="$HYPERX_VOLUME"
    NEW_WP_ID="$(wp_sink_id_by_match "$HYPERX_MATCH")"
else
    NEW_SINK="$CREATIVE_SINK"
    NEW_NAME="$CREATIVE_LABEL"
    NEW_VOLUME="$CREATIVE_VOLUME"
    NEW_WP_ID="$(wp_sink_id_by_match "$CREATIVE_MATCH")"
fi

timeout 3 pactl set-default-sink "$NEW_SINK" >/dev/null 2>&1 || true
if [[ -n "$NEW_WP_ID" ]]; then
    timeout 3 wpctl set-default "$NEW_WP_ID" >/dev/null 2>&1 || true
    timeout 3 wpctl set-volume "$NEW_WP_ID" "$NEW_VOLUME" >/dev/null 2>&1 || true
    timeout 3 wpctl set-mute "$NEW_WP_ID" 0 >/dev/null 2>&1 || true
fi
timeout 3 pactl set-sink-mute "$NEW_SINK" 0 >/dev/null 2>&1 || true
timeout 3 pactl set-sink-volume "$NEW_SINK" "$NEW_VOLUME" >/dev/null 2>&1 || true
move_streams "$NEW_SINK"

FINAL="$(timeout 3 pactl get-default-sink 2>/dev/null || true)"
if [[ "$FINAL" != "$NEW_SINK" ]]; then
    notify "Audio" "Failed to switch to $NEW_NAME"
    exit 1
fi

notify "$NEW_NAME | v $NEW_VOLUME"
echo "Switched audio output to $NEW_SINK"
