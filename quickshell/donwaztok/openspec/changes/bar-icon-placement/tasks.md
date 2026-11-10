# Tasks

## 1. Config

- [x] 1.1 Add `bar.icons` (`status`, `tray`, `hidden` as `list<string>`, empty by default) to `config/BarConfig.qml`, and mark `status.show*`, `status.drives` and `tray.hiddenIcons` as read-only legacy; verify the shell reloads with no new warnings for `BarConfig.qml`.
- [x] 1.2 Confirm `bar.icons` is written by `Config.save()` (`writeAdapter()`), and plan the removal of the legacy declarations for 4.5 so their keys leave the file; verify after a save that the file has `bar.icons`.
- [x] 1.3 Add the one-time migration in `config/Config.qml`: once loaded and all three lists are empty, build them from the legacy keys read from the raw file text (today's status order: lockstatus, audio, microphone, kblayout, drives, network, bluetooth, battery; `hiddenIcons` → `app:<id>` in hidden), copy the file to `config.json.bak-bar-icons`, then save. Verify on a copy of the current `config.json` that the lists come out as status `network, bluetooth, battery`, tray `drives`, hidden the rest, that the backup exists, and that a second reload changes nothing.

## 2. Utils

- [x] 2.1 Create the singleton `utils/BarIcons.qml` (ids, labels, editor glyphs, popout names, view files) and register it in `utils/qmldir`; verify no load errors and that `BarIcons` resolves from the bar and the control center.

## 3. Modules: bar

- [x] 3.1 Move each icon's markup from `modules/bar/components/StatusIcons.qml` into `modules/bar/components/statusIcons/<Name>Icon.qml` (Audio, Microphone, KbLayout, Network, Bluetooth, Drives, Battery, LockStatus), each with `colour` and `inTray`. Verify the status area looks the same as before (screenshot before/after on the vertical bar) with no log warnings.
- [x] 3.2 Make `StatusIcons.qml` a `Repeater` over `Config.bar.icons.status` that loads each view by id and keeps its popout `name`; verify that reordering the list in `config.json` reorders the bar and each icon still opens its popout on hover.
- [x] 3.3 Implement the `inTray` variants (square slot; battery shape scaled; Bluetooth main glyph only; caps lock dimmed glyph when no lock key is on); verify each icon in the tray at the same size as app icons.
- [x] 3.4 Rebuild the `Tray.qml` model in `Config.bar.icons.tray` order (shell ids and `app:` entries), append running apps found in no list, skip hidden ones, and let `TrayItem.qml` load shell views with `inTray: true`. Remove the `"drives"` sentinel code. Verify that apps and shell icons show in the configured order and that a newly started app appears at the end.
- [x] 3.5 Switch the tray hover in `modules/bar/Bar.qml` to `childAt` with the item's popout name, and rename app popouts to `traymenu:<id>` in `Bar.qml` and `modules/bar/popouts/Content.qml`. Verify that hovering every tray item, shell icons and apps alike, opens the right popout, and that app submenus still stay open (`Drawers.qml`/`Interactions.qml` checks).

## 4. Modules: control center

- [ ] 4.1 Create `modules/controlcenter/taskbar/BarIconsEditor.qml` with the three group areas, chips (glyph or app icon plus label), empty-area text and dimmed "Not running" app chips. Verify it shows the current placements in both light and dark schemes.
- [x] 4.2 Add drag and drop (internal drag, insertion marker, Status rejecting app chips, pane scroll disabled while dragging); verify dragging between and within groups updates the bar right away and that a plain swipe still scrolls the pane.
- [ ] 4.3 Add keyboard moves (Left/Right within a group, Up/Down between groups), the move `Menu` (Enter, Menu key, right click) and `Accessible.name`; verify every move works without the mouse and that focus stays on the moved chip.
- [ ] 4.4 Add the info button with `Tooltip` next to the group title (hover, keyboard focus and click); verify all three open it.
- [x] 4.5 Replace the switches and the Drives dropdown in `TaskbarPane.qml` with `BarIconsEditor`, remove the now unused `show*`/`drives` properties and their writes in `saveConfig()`, then remove the legacy `Status` component and `tray.hiddenIcons` from `BarConfig.qml`; verify the pane loads with no warnings, that nothing reads the removed properties (`grep -rn "status.show\|status.drives\|hiddenIcons" --include='*.qml' .`), and that after a save `config.json` has no `bar.status` or `bar.tray.hiddenIcons`.

## 5. Docs

- [x] 5.1 Document `bar.icons` (ids, `app:` prefix, migration backup) in the Configuration section of `CLAUDE.md`; verify the ids listed match `utils/BarIcons.qml`.

## Verification

- [x] 6.1 `qs log -c donwaztok` shows no new warnings or errors for `BarConfig.qml`, `Config.qml`, `BarIcons.qml`, `StatusIcons.qml`, `statusIcons/*`, `Tray.qml`, `TrayItem.qml`, `Bar.qml`, `popouts/Content.qml`, `BarIconsEditor.qml` and `TaskbarPane.qml` after reload and after a few moves in the editor.
- [ ] 6.2 By hand: open Control Center › Taskbar (`hyprctl dispatch 'hl.dsp.global("donwaztok:controlCenter")'`), move every shell icon through Status → Tray → Hidden and back, hide and restore one tray app, and check the bar after each move, including the tray in compact mode and in light and dark schemes.
- [x] 6.3 Hover each icon in the status area and in the tray and check that the right popout opens.

## Workflow follow-up

- Run the `ui-review` agent on the editor and the tray before archiving.
- Archive with `/opsx:archive` after review.
