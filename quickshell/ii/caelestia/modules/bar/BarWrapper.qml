pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.config
import "popouts" as BarPopouts
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    required property bool disabled

    readonly property string position: Config.bar.position === "right" || Config.bar.position === "top" || Config.bar.position === "bottom" ? Config.bar.position : "left"
    readonly property bool isVertical: position === "left" || position === "right"
    readonly property int contentWidth: Config.bar.sizes.thickness
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || visibilities.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    // Margins for content area (only the bar edge is non-zero)
    readonly property int leftMargin: position === "left" ? exclusiveZone : 0
    readonly property int rightMargin: position === "right" ? exclusiveZone : 0
    readonly property int topMargin: position === "top" ? exclusiveZone : 0
    readonly property int bottomMargin: position === "bottom" ? exclusiveZone : 0

    function closeTray(): void {
        content.item?.closeTray();
    }

    function checkPopout(coord: real): void {
        content.item?.checkPopout(coord);
    }

    function handleWheel(coord: real, angleDelta: point): void {
        content.item?.handleWheel(coord, angleDelta);
    }

    visible: isVertical ? (width > Config.border.thickness) : (height > Config.border.thickness)
    implicitWidth: isVertical ? (root.shouldBeVisible ? root.contentWidth : Config.border.thickness) : 0
    implicitHeight: isVertical ? 0 : (root.shouldBeVisible ? root.contentWidth : Config.border.thickness)

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.isVertical ? root.contentWidth : 0
            root.implicitHeight: root.isVertical ? 0 : root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
            Anim {
                target: root
                property: "implicitHeight"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
            Anim {
                target: root
                property: "implicitHeight"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.fill: parent

        active: Config.loaded && (root.shouldBeVisible || root.visible)

        sourceComponent: Bar {
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }
}
