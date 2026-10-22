#!/usr/bin/env python3
# PostToolUse (Edit|Write): after Quickshell hot-reloads, report log warnings that name the edited QML file.
# Silent on success; exits 2 with the matching lines so Claude fixes them.
import json, os, subprocess, sys, time

data = json.load(sys.stdin)
path = data.get("tool_input", {}).get("file_path", "")
root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd", "")
if not path.endswith(".qml") or not root:
    sys.exit(0)
rel = os.path.relpath(os.path.abspath(os.path.join(root, path)), root)
if rel.startswith(".."):
    sys.exit(0)

time.sleep(1.5)  # hot reload is debounced
try:
    log = subprocess.run(["qs", "log", "-c", "donwaztok"], capture_output=True, text=True, timeout=10).stdout
except (OSError, subprocess.TimeoutExpired):
    sys.exit(0)

# Only lines from the latest reload.
lines = log.splitlines()
start = max((i for i, l in enumerate(lines) if "Reloading configuration" in l), default=0)
hits = [l for l in lines[start:] if f"@{rel}" in l or f"/{rel}" in l]
if hits:
    sys.stderr.write(f"Quickshell log after reloading {rel}:\n" + "\n".join(hits[-20:]) + "\n")
    sys.exit(2)
