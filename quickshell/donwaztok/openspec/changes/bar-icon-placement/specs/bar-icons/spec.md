# Spec Delta

## Purpose

Decide where each bar icon appears (the status area, the system tray, or nowhere) and in which order,
for both the shell's own status icons and the tray apps, and let the user change that visually.

## ADDED Requirements

### Requirement: Shell icons have a placement
Each shell status icon (speakers, microphone, keyboard layout, network, Bluetooth, drives, battery,
caps lock) SHALL have exactly one placement: Status, Tray or Hidden. A Status icon SHALL show in the bar's
status area, a Tray icon inside the system tray, and a Hidden icon nowhere.

#### Scenario: Network moved to the tray
- **WHEN** the network icon's placement is Tray
- **THEN** the network glyph appears inside the tray and not in the status area

#### Scenario: Battery hidden
- **WHEN** the battery icon's placement is Hidden
- **THEN** no battery indicator appears anywhere on the bar

### Requirement: Tray apps have a placement
Each system tray app SHALL have a placement of Tray or Hidden; Tray is the default for an app the user
has never placed. A tray app SHALL NOT be placed in Status.

#### Scenario: New app starts
- **WHEN** an app the user never placed adds a tray icon
- **THEN** its icon appears in the tray after the icons the user has already ordered

#### Scenario: App hidden
- **WHEN** the user places a tray app in Hidden
- **THEN** its icon stops showing in the tray, and stays hidden after the app restarts

### Requirement: Order inside a group is kept
Icons in the Status and Tray groups SHALL appear on the bar in the order the user set for that group, in
the bar's direction (top to bottom on a vertical bar, left to right on a horizontal one).

#### Scenario: Reordered status area
- **WHEN** the user moves battery before network in the Status group
- **THEN** the bar shows the battery indicator before the network indicator

#### Scenario: Shell icon among tray apps
- **WHEN** the drives icon is placed in the Tray group between two tray apps
- **THEN** the tray shows it between those two app icons

### Requirement: An icon behaves the same in either group
A shell icon placed in the tray SHALL show the same state as in the status area (for example battery
charge or network signal) and SHALL open the same popout on hover.

#### Scenario: Battery in the tray
- **WHEN** the battery icon is in the tray and the user hovers it
- **THEN** it shows the current charge and the battery popout opens

#### Scenario: Compact tray
- **WHEN** the tray is compact and collapsed
- **THEN** shell icons placed in the tray are hidden with the app icons and appear when the tray expands

### Requirement: Visual placement editor
Control Center › Taskbar SHALL show the three groups as areas listing each icon with its glyph and name.
The user SHALL be able to drag an icon to another group or another position, and the bar SHALL update
right after the drop.

#### Scenario: Drag to Hidden
- **WHEN** the user drags the Bluetooth icon from Status into Hidden
- **THEN** the icon moves to the Hidden area and the Bluetooth indicator leaves the bar

#### Scenario: Tray app dragged to Status
- **WHEN** the user drags a tray app over the Status area
- **THEN** the area does not accept the drop and the app returns to where it was

#### Scenario: Empty group
- **WHEN** a group has no icons
- **THEN** its area stays visible with a short text saying it is empty, so icons can be dropped into it

### Requirement: Icons can be moved without dragging
Every icon in the editor SHALL be movable to another group and to another position with the keyboard and
from a menu, with the same results as dragging.

#### Scenario: Keyboard move
- **WHEN** an icon has keyboard focus and the user uses the move keys
- **THEN** the icon changes position or group as it would by dragging, and focus stays on it

#### Scenario: Menu move
- **WHEN** the user opens an icon's menu and picks a group
- **THEN** the icon moves to the end of that group

### Requirement: Existing settings are migrated
On the first load after the change, placements SHALL be derived from the previous settings so the bar
looks the same: an icon that was on SHALL be in Status, one that was off in Hidden, drives as stored,
and hidden tray apps in Hidden.

#### Scenario: Upgrade with defaults
- **WHEN** the shell loads a config written before this change
- **THEN** the same icons appear in the same places as before the upgrade

#### Scenario: Previously hidden tray app
- **WHEN** a tray app was listed as hidden in the old config
- **THEN** it is in the Hidden group after the upgrade
