pragma Singleton

import "."
import qs.config
import QtQuick

// Control Center layout metrics + aliases to `Colours.shellSurface` (same fill everywhere).
QtObject {
    id: root

    /** Outer inset of split-pane surfaces from the window / pane clip (clears rounded corners). */
    readonly property int splitPaneOuterMargin: Appearance.padding.large

    /** Padding inside each split-pane surface, before scroll content (breathing room vs inner radius). */
    readonly property int splitPaneContentPadding: Appearance.padding.large + Appearance.padding.normal

    /** Tighter chrome for the list column (left) so it does not feel over-padded vs the detail pane. */
    readonly property int splitPaneLeftOuterMargin: Appearance.padding.smaller
    readonly property int splitPaneLeftContentPadding: Appearance.padding.smaller

    /** Inset of pane stack from the main content clip (bottom-right rounded window corner). */
    readonly property int paneStackMargin: Appearance.padding.normal

    readonly property color canvasColor: Colours.shellSurface

    readonly property color shellBackdropColor: Colours.shellSurface

    /** Child surfaces that should show the canvas through (no second paint). */
    readonly property color paneClearColor: "transparent"

    readonly property int headerBarHeight: 52

    /** Vertical rule between sidebar and content; stronger in light mode for pale surfaces. */
    readonly property real sidebarSeparatorOpacity: Colours.light ? 0.42 : 0.36

    /**
     * Same fill as the window + header (`canvasColor`) so there is no seam between chrome and body.
     * Cards/lists still sit above this via `settingsGroupCard` / `m3surfaceContainer*`.
     */
    readonly property color settingsPanelBase: root.canvasColor

    readonly property color navRailSurface: root.settingsPanelBase

    readonly property color settingsContentBackdrop: root.settingsPanelBase

    readonly property color splitPaneListSurface: root.settingsPanelBase

    readonly property color splitPaneDetailSurface: root.settingsPanelBase

    readonly property color splitPaneDivider: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.58 : 0.48)

    readonly property color paneSectionRule: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.34)

    /**
     * Solid fill for grouped preference cards — stepped from unified `canvasColor` so blocks stay visible.
     */
    readonly property color settingsGroupCard: Colours.light
        ? Colours.tPalette.m3surfaceContainerHigh
        : Qt.darker(Colours.shellSurface, 1.12)

    readonly property color settingsGroupCardBorder: Qt.alpha(
        Colours.palette.m3outlineVariant,
        Colours.light ? 0.52 : 0.4)
}
