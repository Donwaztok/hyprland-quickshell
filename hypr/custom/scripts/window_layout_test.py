#!/usr/bin/env python3
"""Self-check for window_layout.py: python3 window_layout_test.py"""
import subprocess

import window_layout
from window_layout import match, shape, unlz4, wait_for_windows, zen_spaces


def client(address, cls, title):
    return {"address": address, "class": cls, "title": title}


def slot(name, cls, title, space=None):
    return {"name": name, "class": cls, "title": title, "space": space}


def placed(pairs):
    return {s["name"]: c["address"] for s, c in pairs}


# LZ4: literals + match, then an overlapping match (offset shorter than its length).
assert unlz4(b"\x40abcd\x04\x00\x10x") == b"abcdabcdx"
assert unlz4(b"\x11a\x01\x00\x10b") == b"aaaaaab"

# The Zen Space decides even when every title changed since the save.
slots = [slot("ducke", "zen", "Ducke", "A"), slot("yt", "zen", "A video", "B"), slot("eng", "zen", "Engenharia", "C")]
live = [client("1", "zen", "Engenharia"), client("2", "zen", "Ducke"), client("3", "zen", "Other tab")]
assert placed(match(slots, live, {"1": "A", "2": "B", "3": "C"})) == {"ducke": "1", "yt": "2", "eng": "3"}

# Without a Space (session unreadable, Space switched), the closest title wins and the rest pair by elimination.
assert placed(match(slots, live, {})) == {"ducke": "2", "eng": "1", "yt": "3"}

# Classes never cross; a saved window with no live match stays unplaced, an unknown live window untouched.
slots = [slot("mail", "thunderbird", "Inbox"), slot("chat", "zapzap", "ZapZap")]
live = [client("1", "zapzap", "ZapZap"), client("2", "kitty", "Inbox")]
assert placed(match(slots, live, {})) == {"chat": "1"}

# Shape ignores split sizes but sees a rotation.
assert shape([[41, 13], [979, 13]]) == shape([[41, 13], [651, 13]]) == [(0, 0), (1, 0)]
assert shape([[41, 13], [41, 545]]) == [(0, 0), (0, 1)]

# Zen titles that say nothing pair by creation order, whatever order hyprctl lists the windows in.
session = [
    {"space": "A", "titles": ["Ducke", "1Password"], "selected": "Ducke"},
    {"space": "B", "titles": ["about:blank", "Ducke CRM"], "selected": "Ducke CRM"},
    {"space": "C", "titles": ["about:blank", "A video"], "selected": "A video"},
]
window_layout.zen_session_windows = lambda: session


def zen(address, stable_id, title):
    return {**client(address, "zen", title), "stableId": stable_id}


generic = [zen("1", "18000002", "Zen Browser"), zen("2", "18000005", "Zen Browser"), zen("3", "1800000a", "Zen Browser")]
expected = {"1": "A", "2": "B", "3": "C"}
assert zen_spaces(generic) == zen_spaces(generic[::-1]) == expected

# A title that matches a tab beats creation order; the generic ones share what is left, in order.
known = [generic[0], generic[1], zen("3", "1800000a", "Ducke — Zen Browser")]
assert zen_spaces(known) == {"3": "A", "1": "B", "2": "C"}

# Boot: done as soon as every saved window exists, even if a title never stops changing,
# and a compositor that does not answer yet is retried instead of killing the script.
slots = [slot("mail", "thunderbird", "Inbox")]
answers = iter([
    subprocess.CalledProcessError(1, "hyprctl"),
    [client("1", "kitty", "◐ working")],
    [client("1", "kitty", "◓ working"), client("2", "thunderbird", "Inbox")],
])


def next_answer():
    answer = next(answers)
    if isinstance(answer, Exception):
        raise answer
    return answer


window_layout.windows = next_answer
window_layout.time.sleep = lambda _: None
wait_for_windows(slots, boot=True)
assert next(answers, None) is None

print("ok")
