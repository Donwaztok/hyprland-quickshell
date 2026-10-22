# Donwaztok (Quickshell)

Desktop shell for Hyprland written in QML on top of Quickshell. Lives inside the
`~/.config` dotfiles repo; the shell root is this directory (`shell.qml`).
`QML2_IMPORT_PATH` points here (set in `~/.config/hypr/lua/hyprland/env.lua`), so
`qs.*` imports resolve from this folder.

Talk to the user in Portuguese (pt-BR). Code, comments, OpenSpec and docs are in English.

## Running and debugging

- Quickshell hot-reloads on save; there is no build step for QML.
- Logs: `qs log -c donwaztok | tail -50`. A PostToolUse hook (`.claude/hooks/qs-log-check.py`)
  waits for the reload after every `.qml` edit and reports log lines that name the edited file;
  fix what it reports. It cannot see surfaces that are not loaded, so open them (below).
- Open surfaces: drawers with `hyprctl dispatch 'hl.dsp.global("donwaztok:<name>")'`
  (Hyprland is configured in Lua, so `hyprctl dispatch` takes Lua; names in
  `modules/Shortcuts.qml`: `dashboard`, `launcher`, `sidebar`, `utilities`, `session`,
  `controlCenter`…); the rest through IPC (`qs ipc -c donwaztok show`; `osdVolume trigger`,
  `region screenshot`/`dismiss`, `cheatsheet open`/`close`). Drawers do not open while a
  fullscreen window is focused. Apps: `fileManager`/`textEditor` `open`, `close` (latest
  window) and `toggle`. Polkit: `pkexec true` in the background, cancel with `pkill -x pkexec`.
  Clicks: `ydotool mousemove --absolute` takes half the global coordinates here; check with
  `hyprctl cursorpos` before `ydotool click 0xC0`. Never type into a window with `wtype` unless
  focus is certain.
- The shell is the only polkit agent; do not start another one (`hypr/lua/hyprland/execs.lua`),
  or the shell's agent fails to register ("An authentication agent already exists").
- The Rust file-manager helper is the only compiled piece:
  `scripts/files/fm-rs/build.sh` builds it into `bin/fm` (used by
  `services/shell/FileManagerService.qml`). `bin/` is not versioned: `shell.qml` builds it on start
  when missing. Rebuild by hand after changing `fm-rs/src`.
- Idle cost check: per-thread CPU of the `qs` process over 20 s (`/proc/<pid>/task/*/stat`)
  and its children (`ps --ppid <pid>`); `strace`/`perf` are not available.

## Layout

- `shell.qml` — entry point; loads `panelFamilies/DonwaztokFamily.qml`.
- `services/` — end-4 singletons for system state (Battery, DeviceBatteries, Audio,
  Notifications, Hyprland*, Weather…). Imported as `qs.services`.
- `services/shell/` — caelestia singletons (`qs.services.shell`): network (`Nmcli`, `VPN`),
  audio, file manager, text editor, wallpapers, `Colours`, `Time`, Hypr helpers.
  **Has an explicit `qmldir`**: new files must be registered there.
- `modules/` — UI: `bar`, `controlcenter`, `dashboard`, `drawers`, `launcher`,
  `lock`, `notifications`, `sidebar`, `session`… `modules/shell/` holds the
  standalone apps (fileManager, textEditor, polkit, OSD, regionSelector…).
- `modules/common/` — end-4 leftovers, non-visual only: `Appearance` (used by `services/`),
  `Config` (the `options` view), `functions/`, `models/`, `utils/`. Its widget set was removed
  on 2026-10-22; every surface uses `components/`.
- `components/`, `utils/` — caelestia building blocks (`StyledRect`, `StateLayer`,
  `MaterialIcon`, `controls/`, `Anim`, `Paths`, `Toaster`…). Use these for new UI.
- `config/` — typed config sections, `Appearance` (caelestia) and `DonwaztokConfigStore.qml`.
- `scripts/` — helper scripts (Python/shell/Rust) called via `Process`.
  Reference them with `Quickshell.shellPath("scripts/...")`.
- `docs/UI-PATTERNS.md` — binding UI and performance rules. `openspec/` — specs and changes.

The codebase merges two upstream styles: caelestia (all UI) and end-4 illogical-impulse
(only non-visual: `services/*.qml` and `modules/common`). UI follows caelestia
(docs/UI-PATTERNS.md §1). Some names exist on both sides (`Appearance`, `Config`, `Audio`,
`Brightness`); when a file needs both, import one side with an alias
(`import qs.services.shell as Shell`).

## Configuration

One file, `$XDG_CONFIG_HOME/donwaztok/config.json`, loaded by `config/DonwaztokConfigStore.qml`,
with two views:

- Caelestia (`import qs.config`): typed sections `Config.bar`, `Config.dashboard`,
  `Config.launcher`… Change a property, then `Config.save()`. Ready flag: `Config.loaded`.
- End-4 (`import qs.modules.common`): the `options` block as `Config.options.<section>.<key>`,
  read with `?.`/`??` defaults (e.g. `Config.options?.battery?.low ?? 20`), written with
  `Config.setNestedValue("section.key", value)`. Ready flag: `Config.ready`.

Use the view of the area you are editing; do not import both `Config`s into one file.

## Conventions

- QML style from `.qmlformat.ini`: 4 spaces, max 110 columns.
- Services start with `pragma Singleton` and `pragma ComponentBehavior: Bound`.
- User-facing strings go through `qsTr()`. UI text and comments are in English.
- External commands: `Process` + `StdioCollector` for output, and
  `Quickshell.execDetached([...])` for fire-and-forget (e.g. `notify-send` with
  `-a Shell`).
- Prefer Material Symbols names for icons (`MaterialSymbol`/`MaterialIcon`).
- For `Shape`, use `preferredRendererType: Shape.GeometryRenderer`.
- A `FileView` whose file may legitimately be missing sets `printErrors: false`.

## Performance (summary of docs/UI-PATTERNS.md §4)

- Poll only while a visible surface consumes the data (`refCount` pattern in
  `services/shell/SystemUsage.qml`); prefer event sources over timers.
- One owner per external stream: `Nmcli` owns `nmcli monitor` and emits `networkChanged`
  (debounced); other services connect to that signal.
- `layer.enabled` only while the effect is visible; gate every `Animation.Infinite`.
- `Time` ticks per minute; nothing shows seconds. Add second precision only where shown.

## How a change flows

Small fixes: edit, let the hook check the log, open the surface. Anything that changes behavior
across surfaces or needs a plan: `/opsx:propose` → `/opsx:apply` → `ui-review` agent →
`/opsx:archive`. Tasks end with a `## Verification` section (see `openspec/config.yaml`).

## Reading budget

- Files over ~800 lines (`modules/shell/fileManager/FileManagerContent.qml` ~4.8k,
  `FileManagerSession.qml`, `services/shell/Nmcli.qml`, `services/shell/Audio.qml`,
  `modules/shell/textEditor/TextEditorContent.qml`, `modules/controlcenter/network/VpnDetails.qml`):
  grep first, then read with offset/limit.
- Do not open `bin/`, `scripts/files/fm-rs/target/`, `__pycache__/` or `assets/` unless asked.
- Before reusing a widget, check it is live (`grep -rlw <Name> --include='*.qml' .`).
  Unreferenced files were removed on 2026-10-22; delete new dead code instead of keeping it.

## Gotchas

- Notifications triggered from polled data (timers, `on…Changed`) must track
  what was already announced and survive devices disappearing between polls;
  otherwise they repeat every refresh (see `evaluateAlerts` in
  `services/DeviceBatteries.qml`).
- Logitech `hidpp_battery_N` paths in UPower are not stable across reconnects;
  key per-device state by normalized name, not by `nativePath`.
- Reloading the shell resets in-memory state in singletons.
- QML singletons are created on first reference: an unreferenced service never runs, and
  referencing one from a new place starts its timers and processes.
- Bindings in a singleton can run before its child objects exist; guard them
  (`clock?.date ?? new Date()` in `services/shell/Time.qml`) or the log fills with
  "Unable to assign [undefined]" on reload.
