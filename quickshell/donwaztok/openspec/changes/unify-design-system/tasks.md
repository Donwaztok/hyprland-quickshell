## 1. Prepare

- [ ] 1.1 Archive `remove-dead-code` first
- [ ] 1.2 For each file below, list the end-4 widgets, `Appearance.colors.*` and `Config.options.*` it uses and pick the caelestia replacement from docs/UI-PATTERNS.md §1

## 2. Port surfaces (one surface per step; reload and check before the next)

- [ ] 2.1 `modules/shell/onScreenDisplay/` (volume/brightness OSD)
- [ ] 2.2 `modules/shell/polkit/`
- [ ] 2.3 `modules/shell/cheatsheet/`
- [ ] 2.4 `modules/shell/regionSelector/` (7 files)
- [ ] 2.5 `modules/bar/components/` (the one file importing `qs.modules.common`)
- [ ] 2.6 `killDialog.qml`, `GlobalStates.qml`, `panelFamilies/`

## 3. Config

- [ ] 3.1 Expose the `Config.options` keys used above through typed `qs.config` sections, reading the same JSON keys

## 4. Cleanup

- [ ] 4.1 Re-run the dead-code scan and delete the `modules/common/widgets` files that became unused
- [ ] 4.2 Update CLAUDE.md and docs/UI-PATTERNS.md §1 (end-4 side is then services-only)

## Verification

- [ ] 5.1 `qs log -c donwaztok` clean for every touched file after reload
- [ ] 5.2 Trigger each surface (volume keys, `pkexec true`, region `qs ipc -c donwaztok call region screenshot`, cheatsheet, kill dialog) in light and dark, with a saturated and a grey wallpaper
