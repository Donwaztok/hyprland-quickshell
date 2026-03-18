import caelestia.components
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper
    required property bool invertBottomRounding
    readonly property string barPosition: Config.bar.position
    readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"
    readonly property real rounding: wrapper.isDetached ? Appearance.rounding.normal : Config.border.rounding
    readonly property real mainSize: isVerticalBar ? wrapper.width : wrapper.height
    readonly property bool flatten: mainSize < rounding * 2
    readonly property real roundingMain: flatten ? mainSize / 2 : rounding
    property real ibr: invertBottomRounding ? -1 : 1

    property real sideRounding: root.barPosition === "right" || root.barPosition === "bottom" ? -1 : 1

    strokeWidth: -1
    fillColor: Colours.palette.m3surface
    fillRule: ShapePath.WindingFill

    PathArc {
        relativeX: root.isVerticalBar ? root.roundingMain : root.rounding * root.sideRounding
        relativeY: root.isVerticalBar ? root.rounding * root.sideRounding : root.roundingMain
        radiusX: root.isVerticalBar ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVerticalBar ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVerticalBar
            ? (root.sideRounding < 0 ? PathArc.Clockwise : PathArc.Counterclockwise)
            : (root.sideRounding < 0 ? PathArc.Counterclockwise : PathArc.Clockwise)
    }
    PathLine {
        relativeX: root.isVerticalBar ? (root.wrapper.width - root.roundingMain * 2) : 0
        relativeY: root.isVerticalBar ? 0 : (root.wrapper.height - root.roundingMain * 2)
    }
    PathArc {
        relativeX: root.isVerticalBar ? root.roundingMain : root.rounding
        relativeY: root.isVerticalBar ? root.rounding : root.roundingMain
        radiusX: root.isVerticalBar ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVerticalBar ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVerticalBar
            ? PathArc.Clockwise
            : (root.barPosition === "top" ? PathArc.Counterclockwise : PathArc.Clockwise)
    }
    PathLine {
        relativeX: root.isVerticalBar ? 0 : (root.wrapper.width - root.rounding * 2)
        relativeY: root.isVerticalBar ? (root.wrapper.height - root.rounding * 2) : 0
    }
    PathArc {
        relativeX: root.isVerticalBar ? -root.roundingMain * root.ibr : root.rounding
        relativeY: root.isVerticalBar ? root.rounding : -root.roundingMain * root.ibr
        radiusX: root.isVerticalBar ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVerticalBar ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVerticalBar
            ? (root.ibr < 0 ? PathArc.Counterclockwise : PathArc.Clockwise)
            : (root.ibr < 0 ? PathArc.Clockwise : PathArc.Counterclockwise)
    }
    PathLine {
        relativeX: root.isVerticalBar ? -(root.wrapper.width - root.roundingMain - root.roundingMain * root.ibr) : 0
        relativeY: root.isVerticalBar ? 0 : -(root.wrapper.height - root.roundingMain - root.roundingMain * root.ibr)
    }
    PathArc {
        relativeX: root.isVerticalBar ? -root.roundingMain : root.rounding * root.sideRounding
        relativeY: root.isVerticalBar ? root.rounding * root.sideRounding : -root.roundingMain
        radiusX: root.isVerticalBar ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVerticalBar ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVerticalBar
            ? (root.sideRounding < 0 ? PathArc.Clockwise : PathArc.Counterclockwise)
            : (root.sideRounding < 0 ? PathArc.Counterclockwise : PathArc.Clockwise)
    }

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on ibr {
        Anim {}
    }

    Behavior on sideRounding {
        Anim {}
    }
}
