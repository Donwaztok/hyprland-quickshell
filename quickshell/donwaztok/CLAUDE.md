# Donwaztok (Quickshell)

Desktop shell for Hyprland written in QML on top of Quickshell. Lives inside the
`~/.config` dotfiles repo; the shell root is this directory (`shell.qml`).
`QML2_IMPORT_PATH` points here (set in `~/.config/hypr/lua/hyprland/env.lua`), so
`qs.*` imports resolve from this folder.

## Running and debugging

- Quickshell hot-reloads on save; there is no build step for QML.
- Logs: `qs log -c donwaztok | tail -50` — check after every edit for QML errors
  (`Unable to assign`, `ReferenceError`, `TypeError`) in the files you touched.
- The Rust file-manager helper is the only compiled piece:
  `scripts/files/fm-rs/build.sh` builds it into `bin/fm` (used by
  `services/shell/FileManagerService.qml`). Rebuild after changing `fm-rs/src`.
  `scripts/files/fm.py` is the older Python version.

## Layout

- `shell.qml` — entry point; loads `panelFamilies/DonwaztokFamily.qml`.
- `services/` — singletons for system state (Battery, DeviceBatteries, Audio,
  Notifications, Hyprland*, Weather…). Imported as `qs.services`.
- `services/shell/` — second set of singletons (`qs.services.shell`): file
  manager, text editor, network/VPN, wallpapers, Hypr helpers. **Has an explicit
  `qmldir`**: new files must be registered there.
- `modules/` — UI: `bar`, `controlcenter`, `dashboard`, `drawers`, `launcher`,
  `lock`, `notifications`, `sidebar`, `session`… `modules/shell/` holds the
  standalone apps (fileManager, textEditor, polkit, OSD, regionSelector…).
- `modules/common/` — `Appearance`, `Config`, `Directories`, `widgets/` (Material
  style widgets: `StyledText`, `RippleButton`, `MaterialSymbol`…), `functions/`.
- `components/`, `utils/` — shared building blocks used by `services/shell` and
  the newer modules (`StyledRect`, `MaterialIcon`, `Paths`, `Toaster`…).
- `config/` — config schema objects and `DonwaztokConfigStore.qml`.
- `scripts/` — helper scripts (Python/shell/Rust) called via `Process`.
  Reference them with `Quickshell.shellPath("scripts/...")`.

The codebase merges two upstream styles (end-4 `illogical-impulse` under
`services/` + `modules/common`, and caelestia-style under `services/shell`,
`components/`, `utils/`, `config/`). Follow the style of the area you are
editing instead of mixing them.

## Configuration

- User config is stored in `$XDG_CONFIG_HOME/donwaztok/config.json`, loaded by
  `config/DonwaztokConfigStore.qml`.
- Read options through `Config.options.<section>.<key>` (`modules/common/Config.qml`),
  using `?.` and `??` defaults (e.g. `Config.options?.battery?.low ?? 20`).
  Wait for `Config.ready` before acting on config values.
- Write with `Config.setNestedValue("section.key", value)`.

## Conventions

- QML style from `.qmlformat.ini`: 4 spaces, max 110 columns.
- Services start with `pragma Singleton` and `pragma ComponentBehavior: Bound`.
- User-facing strings go through `qsTr()`. UI text and comments are in English.
- External commands: `Process` + `StdioCollector` for output, and
  `Quickshell.execDetached([...])` for fire-and-forget (e.g. `notify-send` with
  `-a Shell`).
- Prefer Material Symbols names for icons (`MaterialSymbol`/`MaterialIcon`).
- For `Shape`, use `preferredRendererType: Shape.GeometryRenderer`.

## Gotchas

- Notifications triggered from polled data (timers, `on…Changed`) must track
  what was already announced and survive devices disappearing between polls;
  otherwise they repeat every refresh (see `evaluateAlerts` in
  `services/DeviceBatteries.qml`).
- Logitech `hidpp_battery_N` paths in UPower are not stable across reconnects;
  key per-device state by normalized name, not by `nativePath`.
- Reloading the shell resets in-memory state in singletons.
