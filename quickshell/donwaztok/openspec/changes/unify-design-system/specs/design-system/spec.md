## MODIFIED Requirements

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
