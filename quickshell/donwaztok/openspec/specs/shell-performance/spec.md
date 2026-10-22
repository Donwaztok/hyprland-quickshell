# shell-performance Specification

## Purpose
Keep the always-running shell cheap when idle: no work for data nobody sees, no repeated work for one
event, and no GPU cost for effects that are not visible. Practical guidance lives in docs/UI-PATTERNS.md §4.

## Requirements

### Requirement: Polling is consumer-driven
A timer or `Process` that polls system state SHALL run only while at least one visible surface consumes
its data, and SHALL stop when the last consumer goes away.

#### Scenario: Dashboard resources closed
- **WHEN** no surface showing CPU, memory, storage or network usage is visible
- **THEN** `SystemUsage` and `NetworkUsage` timers are not running and spawn no processes

#### Scenario: Dashboard resources opened
- **WHEN** the dashboard performance tab becomes visible
- **THEN** polling starts at `Config.dashboard.resourceUpdateInterval` and stops again when it closes

### Requirement: Event streams are debounced
A long-running monitor process whose output triggers a refresh SHALL coalesce a burst of lines into one
refresh.

#### Scenario: Network reconnect
- **WHEN** `nmcli monitor` prints several lines for one connection change
- **THEN** `Nmcli` runs one refresh about 300 ms after the last line, not one refresh per line

### Requirement: One owner per external stream
Each external event stream (`nmcli monitor`, audio subscriptions, Hyprland events) SHALL be started by a
single service; other services SHALL react to a signal from that owner.

#### Scenario: VPN status
- **WHEN** the VPN service needs to know that network state changed
- **THEN** it listens to the network service's signal instead of starting its own `nmcli monitor`

### Requirement: Clock precision matches the display
The shared clock SHALL tick at the finest unit any surface displays.

#### Scenario: No surface shows seconds
- **WHEN** every clock surface shows hours and minutes only
- **THEN** `Time` uses `SystemClock.Minutes` and clock bindings re-evaluate once per minute

### Requirement: Effects are active only while visible
An offscreen layer (`layer.enabled` with `OpacityMask` or `MultiEffect`) SHALL be enabled only while the
effect it renders is visible. The full-screen drawer shadow in `modules/drawers/Drawers.qml` is exempt.

#### Scenario: Idle button
- **WHEN** a button that clips a ripple with a mask shows no ripple
- **THEN** its background has no layer and no mask effect

#### Scenario: Pressed button
- **WHEN** the user presses that button
- **THEN** the layer is enabled for the ripple and disabled again once the ripple has faded out

### Requirement: Hidden surfaces are unloaded
Drawer content and standalone apps SHALL not keep their item tree alive while closed, except for the
one-time measurement pass of drawer wrappers at startup.

#### Scenario: Dashboard closed
- **WHEN** the dashboard is closed and its close animation has finished
- **THEN** its content `Loader` is inactive

#### Scenario: File manager closed
- **WHEN** the last file manager window is closed
- **THEN** no file manager window object remains
