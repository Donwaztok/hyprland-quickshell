pragma ComponentBehavior: Bound

import caelestia.components.containers
import caelestia.config
import Quickshell
import QtQuick

Scope {
    id: root

    required property ShellScreen screen
    required property Item bar

    ExclusionZone {
        anchors.left: true
        exclusiveZone: root.bar.leftMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: root.bar.topMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: root.bar.rightMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: root.bar.bottomMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
