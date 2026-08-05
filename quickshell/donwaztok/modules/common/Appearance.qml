import QtQuick
import Quickshell
import qs.services.shell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    /** Applied Material palette — same object as `Colours.current` (see Colours.qml). */
    readonly property QtObject m3colors: Colours.current

    /**
     * Semantic names for legacy components: each maps to a single M3 role from `m3colors`.
     * No mixing, transparency, or overlay math — change the palette in Colours only.
     */
    colors: QtObject {
        property color colSubtext: m3colors.m3onSurfaceVariant
        property color colLayer0Base: m3colors.m3background
        property color colLayer0: m3colors.m3background
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Hover: m3colors.m3surfaceContainerLow
        property color colLayer0Active: m3colors.m3surfaceContainer
        property color colLayer0Border: m3colors.m3outlineVariant
        property color colLayer1Base: m3colors.m3surfaceContainerLow
        property color colLayer1: m3colors.m3surfaceContainerLow
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: m3colors.m3outline
        property color colLayer1Hover: m3colors.m3surfaceContainer
        property color colLayer1Active: m3colors.m3surfaceContainerHigh
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: m3colors.m3surfaceContainer
        property color colLayer2Hover: m3colors.m3surfaceContainerHigh
        property color colLayer2Active: m3colors.m3surfaceContainerHighest
        property color colLayer2Disabled: m3colors.m3surfaceContainerLow
        property color colOnLayer2: m3colors.m3onSurface
        property color colOnLayer2Disabled: m3colors.m3outlineVariant
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: m3colors.m3surfaceContainerHigh
        property color colLayer3Hover: m3colors.m3surfaceContainerHighest
        property color colLayer3Active: m3colors.m3surfaceContainerHighest
        property color colOnLayer3: m3colors.m3onSurface
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: m3colors.m3surfaceContainerHighest
        property color colLayer4Hover: m3colors.m3surfaceContainerHighest
        property color colLayer4Active: m3colors.m3surfaceContainerHighest
        property color colOnLayer4: m3colors.m3onSurface
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: m3colors.m3primary
        property color colPrimaryActive: m3colors.m3primaryContainer
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: m3colors.m3primaryContainer
        property color colPrimaryContainerActive: m3colors.m3primaryContainer
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: m3colors.m3secondaryContainer
        property color colSecondaryActive: m3colors.m3secondaryContainer
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: m3colors.m3secondaryContainer
        property color colSecondaryContainerActive: m3colors.m3onSecondaryContainer
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colTertiary: m3colors.m3tertiary
        property color colTertiaryHover: m3colors.m3tertiaryContainer
        property color colTertiaryActive: m3colors.m3tertiaryContainer
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: m3colors.m3tertiaryContainer
        property color colTertiaryContainerActive: m3colors.m3onTertiaryContainer
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        property color colBackgroundSurfaceContainer: m3colors.m3surfaceContainer
        property color colSurfaceContainerLow: m3colors.m3surfaceContainerLow
        property color colSurfaceContainer: m3colors.m3surfaceContainer
        property color colSurfaceContainerHigh: m3colors.m3surfaceContainerHigh
        property color colSurfaceContainerHighest: m3colors.m3surfaceContainerHighest
        property color colSurfaceContainerHighestHover: m3colors.m3surfaceContainerHighest
        property color colSurfaceContainerHighestActive: m3colors.m3surfaceContainerHighest
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colScrim: m3colors.m3scrim
        property color colShadow: m3colors.m3shadow
        property color colOutline: m3colors.m3outline
        property color colOutlineVariant: m3colors.m3outlineVariant
        property color colError: m3colors.m3error
        property color colErrorHover: m3colors.m3errorContainer
        property color colErrorActive: m3colors.m3error
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: m3colors.m3errorContainer
        property color colErrorContainerActive: m3colors.m3onErrorContainer
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property int unsharpen: 2
        property int unsharpenmore: 6
        property int verysmall: 8
        property int small: 12
        property int normal: 17
        property int large: 23
        property int verylarge: 30
        property int full: 9999
        property int screenRounding: large
        property int windowRounding: 18
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Config.options.appearance.fonts.main
            property string numbers: Config.options.appearance.fonts.numbers
            property string title: Config.options.appearance.fonts.title
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: Config.options.appearance.fonts.iconNerd
            property string monospace: Config.options.appearance.fonts.monospace
            property string reading: Config.options.appearance.fonts.reading
            property string expressive: Config.options.appearance.fonts.expressive
        }
        property QtObject variableAxes: QtObject {
            property var main: ({
                "wght": 450,
                "wdth": 100,
            })
            property var numbers: ({
                "wght": 450,
            })
            property var title: ({ // Slightly bold weight for title
                "wght": 550, // Weight (Lowered to compensate for increased grade)
            })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int smallie: 13
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
        property QtObject barPixelSize: QtObject {
            readonly property real f: Config.options.bar.size
            property int smallest: Math.max(8, Math.round(10 * f))
            property int smaller: Math.max(10, Math.round(12 * f))
            property int smallie: Math.max(11, Math.round(13 * f))
            property int small: Math.max(12, Math.round(15 * f))
            property int normal: Math.max(13, Math.round(16 * f))
            property int large: Math.max(14, Math.round(17 * f))
            property int larger: Math.max(16, Math.round(19 * f))
            property int huge: Math.max(18, Math.round(22 * f))
            property int hugeass: Math.max(19, Math.round(23 * f))
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }

        property QtObject elementResize: QtObject {
            property int duration: 300
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        property QtObject clickBounce: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.clickBounce.duration
                easing.type: root.animation.clickBounce.type
                easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }

        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standardDecel
        }

        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        property real baseBarHeight: Math.round(40 * Config.options.bar.size)
        property real barHeight: Config.options.bar.cornerStyle === 1 ?
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real osdWidth: 260
        property real searchWidthCollapsed: 210
        property real searchWidth: 360
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: Math.round(46 * Config.options.bar.size)
        property real verticalBarWidth: Config.options.bar.cornerStyle === 1 ?
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"
}
