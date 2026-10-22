## Why

The shell mixes two visual languages. Most surfaces use the caelestia primitives (`qs.components`,
`Colours.palette`, `Appearance.anim`), but the OSD, polkit dialog, region selector, cheatsheet, the kill
dialog and one bar component still use the end-4 widgets (`RippleButton`, `StyledText` from
`qs.modules.common.widgets`, `Appearance.colors`). They differ in rounding, state layers, motion curves and
how they follow the transparency setting, so these surfaces look and feel off next to the rest. Keeping
both also means two `Config` views (`Config.<section>` and `Config.options`) and two `Appearance`
singletons for every new contributor to learn.

## What Changes

- Port the remaining end-4 consumers outside `modules/common` to caelestia primitives (16 files):
  `modules/shell/onScreenDisplay` (2), `modules/shell/polkit` (2), `modules/shell/regionSelector` (7),
  `modules/shell/cheatsheet` (1), `modules/bar/components` (1), `killDialog.qml`, `GlobalStates.qml`,
  `panelFamilies` (1).
- Move the `Config.options` keys those files read into typed `qs.config` sections where a section exists;
  keep the JSON keys so existing `config.json` files still load.
- After the port, delete what in `modules/common/widgets` becomes unused (do `remove-dead-code` first).
- `services/*.qml` (end-4 services) are out of scope: they are not visual.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `design-system`: "New UI uses the caelestia primitives" becomes "All shell surfaces use the caelestia
  primitives".

## Impact

- Visual: OSD, polkit, region selector, cheatsheet and kill dialog get caelestia rounding, `StateLayer`
  feedback and `Appearance.anim` motion; colours keep following the wallpaper palette.
- Idle cost: slightly lower (end-4 `RippleButton` instances go away).
- Config: no user-visible migration; JSON keys stay.
- Depends on: `remove-dead-code` (so the port does not touch dead files).
