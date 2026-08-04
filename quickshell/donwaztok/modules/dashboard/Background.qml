import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper

    readonly property string edge: wrapper.edge
    readonly property bool isVertical: wrapper.isVertical
    readonly property real rounding: Config.border.rounding
    readonly property real mainSize: isVertical ? wrapper.width : wrapper.height
    readonly property bool flatten: mainSize < rounding * 2
    readonly property real roundingMain: flatten ? mainSize / 2 : rounding
    property real sideRounding: edge === "right" || edge === "bottom" ? -1 : 1

    startX: edge === "top" || edge === "bottom"
        ? (wrapper.x - rounding * sideRounding)
        : wrapper.x
    startY: edge === "top" || edge === "bottom"
        ? wrapper.y
        : (wrapper.y - rounding * sideRounding)

    strokeWidth: -1
    fillColor: Colours.shellSurface
    fillRule: ShapePath.WindingFill

    PathArc {
        relativeX: root.isVertical ? root.roundingMain : root.rounding * root.sideRounding
        relativeY: root.isVertical ? root.rounding * root.sideRounding : root.roundingMain
        radiusX: root.isVertical ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVertical ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVertical
            ? (root.sideRounding < 0 ? PathArc.Clockwise : PathArc.Counterclockwise)
            : (root.sideRounding < 0 ? PathArc.Counterclockwise : PathArc.Clockwise)
    }
    PathLine {
        relativeX: root.isVertical ? (root.wrapper.width - root.roundingMain * 2) : 0
        relativeY: root.isVertical ? 0 : (root.wrapper.height - root.roundingMain * 2)
    }
    PathArc {
        relativeX: root.isVertical ? root.roundingMain : root.rounding
        relativeY: root.isVertical ? root.rounding : root.roundingMain
        radiusX: root.isVertical ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVertical ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVertical
            ? PathArc.Clockwise
            : (root.edge === "top" ? PathArc.Counterclockwise : PathArc.Clockwise)
    }
    PathLine {
        relativeX: root.isVertical ? 0 : (root.wrapper.width - root.rounding * 2)
        relativeY: root.isVertical ? (root.wrapper.height - root.rounding * 2) : 0
    }
    PathArc {
        relativeX: root.isVertical ? -root.roundingMain : root.rounding
        relativeY: root.isVertical ? root.rounding : -root.roundingMain
        radiusX: root.isVertical ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVertical ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVertical
            ? PathArc.Clockwise
            : PathArc.Counterclockwise
    }
    PathLine {
        relativeX: root.isVertical ? -(root.wrapper.width - root.roundingMain * 2) : 0
        relativeY: root.isVertical ? 0 : -(root.wrapper.height - root.roundingMain * 2)
    }
    PathArc {
        relativeX: root.isVertical ? -root.roundingMain : root.rounding * root.sideRounding
        relativeY: root.isVertical ? root.rounding * root.sideRounding : -root.roundingMain
        radiusX: root.isVertical ? Math.min(root.rounding, root.wrapper.width) : root.rounding
        radiusY: root.isVertical ? root.rounding : Math.min(root.rounding, root.wrapper.height)
        direction: root.isVertical
            ? (root.sideRounding < 0 ? PathArc.Clockwise : PathArc.Counterclockwise)
            : (root.sideRounding < 0 ? PathArc.Counterclockwise : PathArc.Clockwise)
    }

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on sideRounding {
        Anim {}
    }
}
