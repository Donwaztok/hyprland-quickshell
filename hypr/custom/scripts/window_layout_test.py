#!/usr/bin/env python3
"""Self-check for window_layout.py: python3 window_layout_test.py"""
from window_layout import match, unlz4


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

print("ok")
