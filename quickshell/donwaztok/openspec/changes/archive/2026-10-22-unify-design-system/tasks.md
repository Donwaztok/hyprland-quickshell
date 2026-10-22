## 1. Prepare

- [x] 1.1 Archive `remove-dead-code` first
- [x] 1.2 For each file below, list the end-4 widgets, `Appearance.colors.*` and `Config.options.*` it uses and pick the caelestia replacement from docs/UI-PATTERNS.md §1

## 2. Port surfaces (one surface per step; reload and check before the next)

- [x] 2.1 `modules/shell/onScreenDisplay/` (volume/brightness OSD)
- [x] 2.2 `modules/shell/polkit/`
- [x] 2.3 `modules/shell/cheatsheet/`
- [x] 2.4 `modules/shell/regionSelector/` (7 files)
- [x] 2.5 `modules/bar/components/` (the one file importing `qs.modules.common`)
- [x] 2.6 `killDialog.qml`, `GlobalStates.qml`, `panelFamilies/`

## 3. Config

- [x] 3.1 Read the former `Config.options` keys through `qs.config` `Config.shellOptions` (same JSON keys, `??` defaults matching `DonwaztokConfigStore`); no new typed sections were needed

## 4. Cleanup

- [x] 4.1 Re-run the dead-code scan and delete the `modules/common/widgets` files that became unused
- [x] 4.2 Update CLAUDE.md and docs/UI-PATTERNS.md §1 (end-4 side is then services-only)

## Verification

- [x] 5.1 `qs log -c donwaztok` clean for every touched file after reload
- [x] 5.2 Triggered OSD, cheatsheet, region selector and kill dialog; checked log and screenshots. Polkit could not be shown: polkit-gnome owns the agent (see CLAUDE.md)
