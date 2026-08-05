#!/usr/bin/env python3
import json
import subprocess
import sys


def load_json_array(command: list[str]) -> list:
    proc = subprocess.run(command, capture_output=True)
    text = proc.stdout.decode("utf-8", errors="replace")
    start = text.find("[")
    if start < 0:
        return []
    return json.loads(text[start:])


def profile_label(name: str, info: dict) -> str:
    desc = info.get("description")
    if desc and desc not in ("(null)", "null", "None"):
        return str(desc)

    if name == "off":
        return "Off"
    if name == "pro-audio":
        return "Pro Audio"

    parts = []
    for chunk in name.split("+"):
        chunk = chunk.strip()
        if chunk.startswith("output:"):
            parts.append(chunk[7:].replace("-", " "))
        elif chunk.startswith("input:"):
            parts.append("input " + chunk[6:].replace("-", " "))
        else:
            parts.append(chunk.replace("-", " "))
    label = " + ".join(parts).strip()
    return label[:1].upper() + label[1:] if label else name


def list_cards() -> list[dict]:
    cards = load_json_array(["pactl", "-f", "json", "list", "cards"])
    result = []

    for card in cards:
        props = card.get("properties") or {}
        profiles = card.get("profiles") or {}
        active = card.get("active_profile") or "off"

        best_sink = None
        best_source = None
        best_sink_pri = -1
        best_source_pri = -1
        has_sink = False
        has_source = False
        profile_list = []

        for name, info in profiles.items():
            sinks = int(info.get("sinks") or 0)
            sources = int(info.get("sources") or 0)
            priority = int(info.get("priority") or 0)
            available = bool(info.get("available", True))

            profile_list.append(
                {
                    "name": name,
                    "label": profile_label(name, info if isinstance(info, dict) else {}),
                    "sinks": sinks,
                    "sources": sources,
                    "priority": priority,
                    "available": available,
                }
            )

            if name == "off" or not available:
                continue
            if sinks > 0:
                has_sink = True
                if priority > best_sink_pri:
                    best_sink_pri = priority
                    best_sink = name
            if sources > 0:
                has_source = True
                if priority > best_source_pri:
                    best_source_pri = priority
                    best_source = name

        profile_list.sort(key=lambda p: (0 if p["name"] == "off" else 1, -p["priority"], p["name"]))
        preferred = active if active != "off" else (best_sink or best_source or "off")
        active_label = next((p["label"] for p in profile_list if p["name"] == active), active)

        result.append(
            {
                "index": card.get("index"),
                "name": card.get("name") or "",
                "description": props.get("device.description")
                or props.get("device.product.name")
                or props.get("device.nick")
                or card.get("name")
                or "Unknown",
                "activeProfile": active,
                "activeProfileLabel": active_label,
                "enabled": active != "off",
                "hasSink": has_sink,
                "hasSource": has_source,
                "preferredSinkProfile": best_sink or preferred,
                "preferredSourceProfile": best_source or preferred,
                "preferredProfile": preferred,
                "profiles": profile_list,
            }
        )

    return result


def list_monitors() -> list[dict]:
    sources = load_json_array(["pactl", "-f", "json", "list", "sources"])
    result = []

    for source in sources:
        props = source.get("properties") or {}
        name = source.get("name") or ""
        is_monitor = props.get("device.class") == "monitor" or name.endswith(".monitor")
        if not is_monitor:
            continue

        sink_name = source.get("monitor_of_sink") or name.removesuffix(".monitor")
        sink_id = props.get("object.id")
        try:
            sink_id = int(sink_id) if sink_id is not None else -1
        except (TypeError, ValueError):
            sink_id = -1

        raw_description = (
            props.get("device.description")
            or props.get("device.nick")
            or props.get("node.nick")
            or sink_name
            or name
        )
        if not raw_description or raw_description in ("(null)", "null"):
            raw_description = sink_name or name

        description = source.get("description")
        if not description or description in ("(null)", "null"):
            description = f"Monitor of {raw_description}"

        result.append(
            {
                "name": name,
                "sinkName": sink_name,
                "sinkId": sink_id,
                "description": description,
                "muted": bool(source.get("mute")),
            }
        )

    return result


def main() -> int:
    payload = {
        "cards": list_cards(),
        "monitors": list_monitors(),
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
