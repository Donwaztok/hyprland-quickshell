# Proposal

## Why

Each bar status icon can only be switched on or off, and the system tray apps can only be hidden by
editing `bar.tray.hiddenIcons` in the JSON. The drives icon just gained a third choice (status area, tray,
or hidden) through a dropdown that looks out of place among the switches. The user wants that choice for
every icon, set in one visual place by dragging icons between groups.

## What Changes

- Every shell status icon (speakers, microphone, keyboard layout, network, Bluetooth, drives, battery,
  caps lock) can be placed in one of three groups: **Status** (the bar's status area), **Tray** (inside
  the system tray, after the app icons) or **Hidden**. Icons keep a user-defined order inside each group,
  and the bar shows them in that order.
- System tray apps (status notifier items such as blueman or ZapZap) appear in the same editor. They can
  move between **Tray** and **Hidden** and be reordered; they cannot go to **Status**.
- An icon placed in the tray looks the same as in the status area and opens the same popout on hover.
- Control Center › Taskbar › Status icons: the per-icon switches and the Drives dropdown are replaced by a
  visual editor with three group areas that show each icon's glyph (Material symbol for shell icons, the
  app's own icon for tray apps). Icons are dragged between groups and within a group. Each icon also has a
  non-drag way to move it (keyboard and a menu).
- **BREAKING** (config): `bar.status.show*` booleans, `bar.status.drives` and `bar.tray.hiddenIcons` are
  replaced by an ordered placement structure. Existing values are migrated once on load
  (`show*: true` → Status, `false` → Hidden; `drives` as stored; `hiddenIcons` entries → Hidden), so the
  bar looks the same after the upgrade.

## Capabilities

### New Capabilities
- `bar-icons`: where each bar icon (shell status icons and tray apps) is shown, in which order, and how the
  user changes that from the Control Center.

### Modified Capabilities
<!-- None: the editor is built from caelestia primitives, so design-system requirements still hold
     unchanged, and nothing here polls or adds always-on effects (shell-performance unchanged). -->

## Impact

- Design system: caelestia only (`qs.components`, `qs.components.controls`, `qs.config`). No end-4 code
  is touched.
- Idle cost: none added. No timers or processes; the tray reuses the bindings the status icons already
  have, and an icon is instantiated in one place only (status area or tray), never both. Dragging only
  runs while the Control Center pane is open.
- Code: `config/BarConfig.qml`, `config/Config.qml` (serialization and migration),
  `modules/bar/components/StatusIcons.qml`, `Tray.qml`, `TrayItem.qml`, `modules/bar/Bar.qml` (tray hover
  resolution), `modules/bar/popouts/Content.qml` (tray menu popouts), and
  `modules/controlcenter/taskbar/TaskbarPane.qml` plus a new editor component under
  `modules/controlcenter/taskbar/`.
- Config file: `~/.config/donwaztok/config.json` is rewritten in the new shape on the first save after
  migration; the old keys are dropped.
