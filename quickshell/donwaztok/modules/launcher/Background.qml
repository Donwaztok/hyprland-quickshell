import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper
    readonly property real rounding: Config.border.rounding
    readonly property real safeHeight: Math.max(
        wrapper.height,
        wrapper.implicitHeight,
        wrapper.contentHeight ?? 0,
        Config.launcher.sizes.searchBarHeight
    )
    readonly property real safeWidth: Math.max(wrapper.width, Config.launcher.sizes.itemWidth)
    readonly property bool flatten: root.safeWidth < root.rounding * 2
    readonly property real roundingX: root.flatten ? root.safeWidth / 2 : Math.min(root.rounding, root.safeWidth / 2)

    strokeWidth: -1
    fillColor: Colours.shellSurface

    // Simple rounded rect — no bottom edge flares (those only made sense when docked to the screen bottom).
    PathArc {
        relativeX: -root.roundingX
        relativeY: root.rounding
        radiusX: Math.min(root.rounding, root.safeWidth)
        radiusY: root.rounding
    }
    PathLine {
        relativeX: -(root.safeWidth - root.roundingX * 2)
        relativeY: 0
    }
    PathArc {
        relativeX: -root.roundingX
        relativeY: root.rounding
        radiusX: Math.min(root.rounding, root.safeWidth)
        radiusY: root.rounding
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: 0
        relativeY: root.safeHeight - root.rounding * 2
    }
    PathArc {
        relativeX: root.roundingX
        relativeY: root.rounding
        radiusX: Math.min(root.rounding, root.safeWidth)
        radiusY: root.rounding
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: root.safeWidth - root.roundingX * 2
        relativeY: 0
    }
    PathArc {
        relativeX: root.roundingX
        relativeY: root.rounding
        radiusX: Math.min(root.rounding, root.safeWidth)
        radiusY: root.rounding
    }

    Behavior on fillColor {
        CAnim {}
    }
}
