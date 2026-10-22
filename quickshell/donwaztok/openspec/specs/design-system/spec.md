# design-system Specification

## Purpose
Give every shell surface one visual language: Material 3 tokens from the wallpaper-driven palette, the
caelestia primitives in `components/`, and shared animation timings. Practical guidance lives in
docs/UI-PATTERNS.md §1–3.

## Requirements

### Requirement: Colours come from the palette
Surfaces SHALL take colours from `Colours.palette` or `Colours.tPalette` (or, in legacy end-4 files,
`Appearance.colors`). Literal colours SHALL appear only as fallbacks for a missing token.

#### Scenario: Wallpaper change
- **WHEN** the wallpaper, and so the generated palette, changes
- **THEN** every visible surface recolours without a reload

#### Scenario: Light and dark
- **WHEN** the scheme switches between light and dark
- **THEN** text keeps contrast against its surface on every surface

### Requirement: New UI uses the caelestia primitives
All shell surfaces SHALL be built from `qs.components` (`StyledRect`, `StyledText`, `MaterialIcon`,
`StateLayer`, `qs.components.controls`) and `qs.config` (`Config.<section>`, `Appearance`). No file outside
`services/` SHALL import `qs.modules.common.widgets`.

#### Scenario: Adding a settings row
- **WHEN** a new toggle is added to a control center pane
- **THEN** it uses `SwitchRow`/`StyledSwitch` from `qs.components.controls`, not `ConfigSwitch`

#### Scenario: Polkit prompt
- **WHEN** a polkit authentication dialog opens
- **THEN** its buttons, field and motion match the control center (caelestia primitives and `Appearance.anim`)

### Requirement: Shared motion
Animations SHALL use `Anim`/`CAnim` with durations and curves from `Appearance.anim`, so the global
animation scale applies to them.

#### Scenario: Animation scale
- **WHEN** the user changes the animation duration scale
- **THEN** panel, button and list animations all speed up or slow down together

### Requirement: Data surfaces show their state
A surface that loads data SHALL show a loading state, an error state with icon and text, and an explicit
empty state.

#### Scenario: Network list empty
- **WHEN** a Wi-Fi scan returns no networks
- **THEN** the list says so in text instead of showing a blank area

### Requirement: Status is not colour alone
A status (error, warning, connected, charging) SHALL be shown by an icon or text in addition to colour.

#### Scenario: Low battery
- **WHEN** a battery is below its alert threshold
- **THEN** the indicator changes icon as well as colour
