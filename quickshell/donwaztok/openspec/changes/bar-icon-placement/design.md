# Design

## Context

See proposal.md (Why) and specs/bar-icons/spec.md for the required behavior. Current state:

- `modules/bar/components/StatusIcons.qml` (423 lines) holds every status icon inline, each in a
  `WrappedLoader` with a popout `name` and `active: Config.bar.status.show*`. Order is fixed by the file.
  Speakers and microphone both open the `audio` popout. Bluetooth also lists connected devices; battery
  draws a custom shape; caps lock shows only while a lock key is on.
- `Tray.qml` builds its model from `SystemTray.items` minus `Config.bar.tray.hiddenIcons`, plus a
  `"drives"` sentinel added at the end when `bar.status.drives === "tray"`. `TrayItem.qml` draws either an
  app icon or the drives glyph.
- `Bar.qml` finds the hovered tray item by arithmetic (`coord / layoutSize * count`), which assumes every
  tray slot has the same size, and names app popouts `traymenu${index}`; `popouts/Content.qml` creates one
  popout per app with the same index over its own filtered list. `Drawers.qml` and `Interactions.qml`
  test `currentName.startsWith("traymenu")`.
- Config: `config/BarConfig.qml` (typed `JsonObject`s) is persisted by `Config.save()`, which calls
  `writeAdapter()`: every declared property is written and undeclared keys are dropped from the file.
  (`serializeConfig()`/`serialize*()` in `Config.qml` are not called by anything.)
  `~/.config/donwaztok/config.json` is not versioned.

## Goals / Non-Goals

**Goals:**
- One description of each shell icon (label, editor glyph, popout, view) shared by the bar, the tray
  and the editor.
- Tray hit-testing that works with slots of different sizes and any order.

**Non-Goals:**
- Moving icons between bar entries other than the status area and the tray (workspaces, clock…).
- Per-monitor placements: one placement applies to every bar.
- Pruning config entries of apps that were uninstalled.

## Decisions

### Config: three ordered id lists
`bar.icons` holds `status`, `tray` and `hidden`, each a `list<string>`. Shell icons use fixed ids
(`audio`, `microphone`, `kblayout`, `network`, `bluetooth`, `drives`, `battery`, `lockstatus`); tray
apps use `app:<status notifier id>`. A running app found in no list is shown at the end of the tray.
Defaults reproduce today's bar: status `network, bluetooth, battery`; tray `drives`; hidden the rest.
*Alternative:* a `{placement, order}` object per icon. Rejected: drag-and-drop is an array move, and three
arrays make order and group one value with no duplicate positions.

### Migration once, in code
When the config has loaded and all three `icons` lists are empty, `Config.qml` builds the lists from the
legacy keys (`bar.status.show*`, `bar.status.drives`, `bar.tray.hiddenIcons`), read from the raw file text
with the old defaults for missing keys, in the fixed order of today's status area. It then copies the
config file to `config.json.bak-bar-icons` and saves. Because the migration reads the raw text, the legacy
declarations are removed from `BarConfig.qml` once nothing else reads them, and `writeAdapter()` then
drops those keys from the file.
*Alternative:* a one-off script that edits `config.json`. Rejected: a restored or older config would load
with every icon on its defaults.

### Icon registry and one file per icon
A singleton `utils/BarIcons.qml` maps each shell id to its label, editor glyph, popout name and view file.
Each icon's markup moves out of `StatusIcons.qml` into `modules/bar/components/statusIcons/<Name>Icon.qml`
with a `colour` property and an `inTray` flag. With `inTray`, an icon fits the tray's square slot: the
battery shape is scaled to the slot, and Bluetooth shows its main glyph without the connected-device list.
`StatusIcons.qml` becomes a `Repeater` over `Config.bar.icons.status` with a `Loader` per id; the tray
model holds shell ids and app items in `Config.bar.icons.tray` order, and `TrayItem.qml` loads the same
view file with `inTray: true`.
*Alternative:* keep the components inline in `StatusIcons.qml` and expose them. Rejected: the tray would
depend on an instance of the status area, and the file would keep growing.

### Hit-testing and popout names
The tray hover in `Bar.qml` uses `childAt` and walks up to the nearest item with a `popoutName`, as the
status area already does, instead of index arithmetic. App popouts are named `traymenu:<id>`, in both
`Bar.qml` and `popouts/Content.qml`, so their names no longer depend on list order. The existing
`startsWith("traymenu")` checks still hold.

### Editor component
`modules/controlcenter/taskbar/BarIconsEditor.qml` replaces the switches in the "Status icons" group. It
has three areas (`StyledRect` with a `Flow` of chips and a `DropArea`). Each chip shows a `MaterialIcon`
for shell icons, or the app's `IconImage` for apps, plus a `StyledText` label.
- Drag: a `DragHandler` with `target: null` moves a floating copy with `Drag.active`, using internal drag
  (`Drag.keys: ["bar-icon"]`, not `Drag.Automatic`, since source and target share a window). The handler
  takes the grab on its drag threshold, so the pane's `Flickable` still scrolls on a plain swipe. The
  `DropArea` computes the insert index from the drop point over the `Flow` children and shows an insertion
  marker. The Status area rejects app chips in `onEntered` (`drag.accepted = false`).
- Keyboard: chips take focus with Tab. Left and Right move a chip within its group; Up and Down move it to
  the previous or next group (at the same index, clamped). Enter, the Menu key or a right click opens a
  `Menu` (`qs.components.controls`) with "Move to Status / Tray / Hidden"; app chips have no Status entry.
  `Accessible.name` reads "<label>, <group>".
- Apps listed in config but not running show dimmed with "Not running", so a hidden app can be found and
  restored. Empty areas show "Empty — drop icons here".
- The "drag icons between groups" hint is an info icon next to the group title, not a paragraph: a
  focusable `IconButton` with an `Accessible.name` that shows `components/controls/Tooltip.qml` on hover,
  on keyboard focus and on click (touch has no hover). The tooltip is driven by its caller through
  `tooltipVisible`.
- Every move writes the three lists and calls `Config.save()`; the bar follows through bindings.

### Loading and idle cost
The editor exists only while the Control Center Taskbar pane is open, because the pane already loads
lazily. No timers or processes are added. An icon is instantiated only in the group where it is placed,
so moving one to the tray does not double its bindings (UI-PATTERNS §4).

## Risks / Trade-offs

- [Tray slots of different sizes break layout and the hover] → views have a fixed square size when
  `inTray`, and the hover switches to `childAt`.
- [Migration writes a wrong layout] → a backup is copied before the first save, and migration runs only
  while all three lists are empty, so it never runs twice.
- [Drag fights the pane's scrolling] → `DragHandler` takes the grab only past its drag threshold, and
  `Flickable.interactive` is turned off while a chip is dragged.
- [Status notifier ids can change between app versions] → the old entry then shows as "Not running", and
  the app reappears at the end of the tray, where the user can place it again.
- [Caps lock in the tray is empty while no lock key is on] → in the tray, its view shows a dimmed lock
  glyph instead of collapsing, so slots keep their size.

## Migration Plan

1. Ship the code. On the next load, the shell migrates `config.json` once, writes the backup and saves.
2. Rollback: revert the commit and copy `config.json.bak-bar-icons` back to `config.json`.
