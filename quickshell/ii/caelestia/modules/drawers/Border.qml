pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property Item bar

    anchors.fill: parent

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surface
        // Reduce sub-pixel fringe / driver noise at monitor edges when masking with MultiEffect.
        layer.smooth: true
        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.35
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: Config.border.thickness
            anchors.leftMargin: Math.max(Config.border.thickness, root.bar.leftMargin)
            anchors.rightMargin: Math.max(Config.border.thickness, root.bar.rightMargin)
            anchors.topMargin: Math.max(Config.border.thickness, root.bar.topMargin)
            anchors.bottomMargin: Math.max(Config.border.thickness, root.bar.bottomMargin)
            radius: Config.border.rounding
        }
    }
}
