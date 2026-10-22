## Why

About 15% of the QML (109 files, ~6.8k lines, plus a 168 KB vendored shape library and the 80 KB legacy
`fm.py`) is never instantiated. It came with the end-4 and caelestia merges and with the move from `fm.py`
to `fm-rs`. Dead files cost nothing at runtime (QML singletons and types load on first use), but they mislead
reviews and agents: they look like live patterns (`RippleButtonWithIcon`, `ConfigSwitch`, quick-toggle
models, `WirelessPane`) and get copied.

## What Changes

- Delete every QML file whose type name is not referenced by any live QML, `qmldir` or JS file, repeated
  until stable. The list is in `tasks.md`.
- Delete `modules/common/widgets/shapes/` (only dead widgets import it).
- Delete orphan scripts: `scripts/files/fm.py`, `scripts/colors/random/`, `scripts/hyprland/get_keybinds.py`.
- No behavior change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (no requirement changes; this only removes unused code).

## Impact

- Design system: mostly end-4 (`modules/common`), which shrinks to what is still used.
- Idle cost: none (dead code never ran).
- Risk: a type loaded by a string path the scan missed. Mitigation: task 4.1 re-runs the scan, and 4.3
  opens every surface after the reload.
