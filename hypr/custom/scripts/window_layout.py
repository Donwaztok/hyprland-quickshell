#!/usr/bin/env python3
"""Save where the open windows are and put them back: window_layout.py save | restore [--boot].

Nothing here pins a window to a workspace: until the next restore, windows go anywhere.
"""
import glob
import json
import os
import subprocess
import sys
import time
from difflib import SequenceMatcher

LAYOUT = os.path.expanduser("~/.local/state/donwaztok/window-layout.json")
ZEN_SESSIONS = "~/.zen/*/sessionstore-backups/recovery.jsonlz4"
ZEN_TITLE_SUFFIX = " — Zen Browser"


def hypr(what):
    return json.loads(subprocess.check_output(["hyprctl", "-j", what]))


def dispatch(lua):
    subprocess.run(["hyprctl", "dispatch", lua], stdout=subprocess.DEVNULL)


def notify(text):
    subprocess.run(["notify-send", "-a", "Window layout", text], check=False)


def windows():
    return [c for c in hypr("clients") if c["mapped"] and not c["hidden"] and c["class"]]


def ratio(a, b):
    return SequenceMatcher(None, a, b).ratio()


def pair(left, right, score):
    """Best-first one-to-one pairing; a negative score means the two can never pair."""
    scored = [(score(a, b), i, j) for i, a in enumerate(left) for j, b in enumerate(right)]
    used_left, used_right, pairs = set(), set(), []
    for s, i, j in sorted(scored, key=lambda t: -t[0]):
        if s >= 0 and i not in used_left and j not in used_right:
            used_left.add(i)
            used_right.add(j)
            pairs.append((left[i], right[j]))
    return pairs


def unlz4(data):
    """Decode a raw LZ4 block; python-lz4 is not installed and this is all Zen's session needs."""
    out, i = bytearray(), 0
    while i < len(data):
        token = data[i]
        i += 1
        literals = token >> 4
        if literals == 15:
            while True:
                literals += data[i]
                i += 1
                if data[i - 1] != 255:
                    break
        out += data[i : i + literals]
        i += literals
        if i >= len(data):
            break
        offset = data[i] | data[i + 1] << 8
        i += 2
        length = token & 15
        if length == 15:
            while True:
                length += data[i]
                i += 1
                if data[i - 1] != 255:
                    break
        length += 4
        if offset >= length:
            out += out[-offset : -offset + length or None]
        else:
            for _ in range(length):
                out.append(out[-offset])
    return bytes(out)


def zen_session_windows():
    """Each Zen window's Space and tab titles, from the session file Zen keeps up to date."""
    try:
        path = max(glob.glob(os.path.expanduser(ZEN_SESSIONS)), key=os.path.getmtime)
        with open(path, "rb") as f:
            session = json.loads(unlz4(f.read()[12:]))  # 8-byte magic + 4-byte size
    except (OSError, ValueError, IndexError):
        return []
    result = []
    for w in session["windows"]:
        titles = [
            t["entries"][t.get("index", 1) - 1].get("title") or "" if t.get("entries") else ""
            for t in w["tabs"]
        ]
        selected = w.get("selected", 1) - 1
        result.append({
            "space": w.get("activeZenSpace"),
            "titles": titles,
            "selected": titles[selected] if selected < len(titles) else "",
        })
    return result


def zen_spaces(clients):
    """address -> Zen Space. The Space survives tab changes and restarts; the title does neither."""
    zen = [c for c in clients if c["class"] == "zen"]
    if not zen:
        return {}

    def score(client, session_window):
        title = client["title"].removesuffix(ZEN_TITLE_SUFFIX)
        best_tab = max((ratio(title, t) for t in session_window["titles"]), default=0)
        return best_tab + ratio(title, session_window["selected"])

    return {c["address"]: s["space"] for c, s in pair(zen, zen_session_windows(), score)}


def match(slots, clients, spaces):
    """Pair saved windows with live ones of the same class: same Zen Space first, then closest title."""

    def score(slot, client):
        if slot["class"] != client["class"]:
            return -1
        same_space = slot.get("space") and slot["space"] == spaces.get(client["address"])
        return ratio(slot["title"], client["title"]) + (2 if same_space else 0)

    return pair(slots, clients, score)


def save():
    clients = windows()
    spaces = zen_spaces(clients)
    monitors = {m["id"]: m["name"] for m in hypr("monitors")}
    slots = []
    for c in clients:
        try:
            with open(f"/proc/{c['pid']}/cmdline", "rb") as f:
                argv = [a.decode(errors="surrogateescape") for a in f.read().split(b"\0") if a]
            cwd = os.readlink(f"/proc/{c['pid']}/cwd")
        except OSError:  # exited between the listing and here: still worth placing, just not launching
            argv, cwd = [], None
        slots.append({
            "class": c["class"],
            "title": c["title"],
            "space": spaces.get(c["address"]),
            "workspace": c["workspace"]["name"],
            "monitor": monitors.get(c["monitor"]),
            "at": c["at"],
            "size": c["size"],
            "floating": c["floating"],
            "pid": c["pid"],
            "argv": argv,
            "cwd": cwd,
        })
    os.makedirs(os.path.dirname(LAYOUT), exist_ok=True)
    with open(LAYOUT + ".tmp", "w") as f:
        json.dump(slots, f, indent=1)  # keep ASCII escapes: argv may hold non-UTF-8 surrogates
    os.replace(LAYOUT + ".tmp", LAYOUT)
    notify(f"Layout saved: {len(slots)} windows")


def running_argvs():
    argvs = set()
    for path in glob.glob("/proc/[0-9]*/cmdline"):
        try:
            with open(path, "rb") as f:
                argvs.add(f.read())
        except OSError:
            pass
    return argvs


def launch_missing(slots, clients):
    """Start apps with no window yet, once per saved process (Zen's 3 windows are one process)."""
    open_classes = {c["class"] for c in clients}
    alive = running_argvs()
    launched, seen = False, set()
    for s in slots:
        if s["class"] in open_classes or not s["argv"] or s["pid"] in seen:
            continue
        seen.add(s["pid"])
        # shortcut: 2 windows of a single-instance app (kitty -1) reopen as 1, split into one process per window if it matters
        if "\0".join(s["argv"]).encode(errors="surrogateescape") + b"\0" in alive:
            continue
        cwd = s["cwd"] if s["cwd"] and os.path.isdir(s["cwd"]) else None
        subprocess.Popen(s["argv"], cwd=cwd, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        launched = True
    return launched


def wait_for_windows(slots, boot):
    """Boot: apps are still starting, so wait for them and for their titles to stop changing."""
    start = time.monotonic()
    launch_at = start + (15 if boot else 0)  # gives the autostart apps time to appear first
    launched = attempted = False
    last, stable_since = None, start
    while True:
        clients = windows()
        now = time.monotonic()
        state = sorted((c["address"], c["title"]) for c in clients)
        if state != last:
            last, stable_since = state, now
        if not attempted and now >= launch_at:
            attempted = True
            launched = launch_missing(slots, clients)
        have = {}
        for c in clients:
            have[c["class"]] = have.get(c["class"], 0) + 1
        for s in slots:
            have[s["class"]] = have.get(s["class"], 0) - 1
        complete = all(n >= 0 for n in have.values())
        settled = now - stable_since >= 5 or not (boot or launched)
        if complete and settled and attempted:
            return
        if attempted and not boot and not launched:
            return
        if now - start >= (60 if boot else 30):
            return
        time.sleep(1)


def lua_workspace(name):
    return name if name.lstrip("-").isdigit() else json.dumps(name, ensure_ascii=False)


def apply(slots):
    clients = windows()
    pairs = match(slots, clients, zen_spaces(clients))

    for slot, c in pairs:
        target = f'window = "address:{c["address"]}"'
        if slot["floating"] != c["floating"]:
            dispatch(f'hl.dsp.window.float({{ action = "{"enable" if slot["floating"] else "disable"}", {target} }})')
        if slot["workspace"] != c["workspace"]["name"]:
            dispatch(f'hl.dsp.window.move({{ workspace = {lua_workspace(slot["workspace"])}, follow = false, {target} }})')
    time.sleep(0.2)

    # Monitors last: a workspace may only exist now that its windows moved in.
    current = {w["name"]: w["monitor"] for w in hypr("workspaces")}
    for name, monitor in {s["workspace"]: s["monitor"] for s, _ in pairs}.items():
        if monitor and not name.startswith("special") and current.get(name) not in (None, monitor):
            dispatch(f'hl.dsp.workspace.move({{ workspace = {lua_workspace(name)}, monitor = "{monitor}" }})')
    time.sleep(0.2)

    groups = {}
    for slot, c in pairs:
        if not slot["floating"]:
            groups.setdefault(slot["workspace"], []).append((slot, c["address"]))
    for group in groups.values():
        arrange_tiled(group)

    for slot, c in pairs:
        if slot["floating"]:
            target = f'window = "address:{c["address"]}"'
            dispatch(f'hl.dsp.window.resize({{ x = {slot["size"][0]}, y = {slot["size"][1]}, {target} }})')
            dispatch(f'hl.dsp.window.move({{ x = {slot["at"][0]}, y = {slot["at"][1]}, {target} }})')
    return len(pairs)


def shape(positions):
    """Each window's column and row rank: the same arrangement gives the same shape at any split size."""
    xs = sorted({p[0] for p in positions})
    ys = sorted({p[1] for p in positions})
    return [(xs.index(p[0]), ys.index(p[1])) for p in positions]


def extent(rects):
    """Width and height of the area covered by (position, size) pairs."""
    return (
        max(at[0] + size[0] for at, size in rects) - min(at[0] for at, _ in rects),
        max(at[1] + size[1] for at, size in rects) - min(at[1] for at, _ in rects),
    )


def toggle_split(address):
    """togglesplit only acts on the focused window, so focus it and put the view back afterwards."""
    active = hypr("activewindow").get("address")
    shown = {m["name"]: m["activeWorkspace"]["name"] for m in hypr("monitors")}
    dispatch(f'hl.dsp.focus({{ window = "address:{address}" }})')
    dispatch('hl.dsp.layout("togglesplit")')
    for m in hypr("monitors"):
        if shown.get(m["name"], m["activeWorkspace"]["name"]) != m["activeWorkspace"]["name"]:
            dispatch(f'hl.dsp.focus({{ workspace = {lua_workspace(shown[m["name"]])} }})')
    if active:
        dispatch(f'hl.dsp.focus({{ window = "address:{active}" }})')


def arrange_tiled(group):
    """Swap windows until their order matches, fix a rotated split, then restore the split sizes."""
    group.sort(key=lambda g: (g[0]["at"][0], g[0]["at"][1]))
    addresses = [a for _, a in group]
    for i, want in enumerate(addresses):
        live = {c["address"]: c for c in windows()}
        order = sorted((a for a in addresses if a in live), key=lambda a: (live[a]["at"][0], live[a]["at"][1]))
        if order[i] != want:
            dispatch(f'hl.dsp.window.swap({{ window = "address:{want}", target = "address:{order[i]}" }})')
    if len(group) < 2:
        return
    saved = [slot["at"] for slot, _ in group]
    live = {c["address"]: c for c in windows()}
    if len(group) == 2 and shape(saved) != shape([live[a]["at"] for a in addresses]):
        toggle_split(addresses[0])
        time.sleep(0.2)
        live = {c["address"]: c for c in windows()}
    # shortcut: dwindle's tree is not rebuilt, so 3+ windows arranged differently stay that way; save the tree if that matters
    if shape(saved) != shape([live[a]["at"] for a in addresses]):
        return  # forcing saved sizes onto another arrangement crushes one window to a sliver
    # Proportional, not saved pixels: a hidden workspace that just changed monitor still reports its old geometry.
    saved_w, saved_h = extent([(slot["at"], slot["size"]) for slot, _ in group])
    live_w, live_h = extent([(live[a]["at"], live[a]["size"]) for a in addresses])
    for slot, address in group:
        x = round(slot["size"][0] * live_w / saved_w)
        y = round(slot["size"][1] * live_h / saved_h)
        size = live[address]["size"]
        if abs(size[0] - x) > 2 or abs(size[1] - y) > 2:
            dispatch(f'hl.dsp.window.resize({{ x = {x}, y = {y}, window = "address:{address}" }})')


def restore(boot):
    try:
        with open(LAYOUT) as f:
            slots = json.load(f)
    except (OSError, ValueError):
        if not boot:
            notify("No saved layout yet")
        return
    wait_for_windows(slots, boot)
    placed = apply(slots)
    if not boot:
        notify(f"Layout restored: {placed}/{len(slots)} windows")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "save":
        save()
    elif command == "restore":
        restore("--boot" in sys.argv)
    else:
        sys.exit(__doc__)
