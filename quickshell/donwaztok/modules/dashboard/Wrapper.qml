pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    readonly property PersistentProperties dashState: PersistentProperties {
        property int currentTab
        property date currentDate: new Date()

        reloadableId: "dashboardState"
    }

    readonly property string edge: {
        const p = Config.dashboard.position;
        if (p === "follow-bar")
            return Config.bar.position;
        if (p === "bottom" || p === "left" || p === "right")
            return p;
        return "top";
    }
    readonly property bool isVertical: edge === "left" || edge === "right"

    readonly property real nonAnimHeight: content.item?.nonAnimHeight ?? 0
    readonly property real nonAnimWidth: content.item?.nonAnimWidth ?? 0

    visible: isVertical ? width > 0 : height > 0
    implicitHeight: {
        if (isVertical)
            return nonAnimHeight;
        return state === "visible" ? nonAnimHeight : 0;
    }
    implicitWidth: {
        if (!isVertical)
            return nonAnimWidth;
        return state === "visible" ? nonAnimWidth : 0;
    }

    onStateChanged: {
        if (state === "visible" && timer.running) {
            timer.triggered();
            timer.stop();
        }
    }

    states: State {
        name: "visible"
        when: root.visibilities.dashboard && Config.dashboard.enabled
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                properties: "implicitHeight,implicitWidth"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                properties: "implicitHeight,implicitWidth"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Timer {
        id: timer

        running: true
        interval: Appearance.anim.durations.extraLarge
        onTriggered: {
            content.active = Qt.binding(() => (root.visibilities.dashboard && Config.dashboard.enabled) || root.visible);
            content.visible = true;
        }
    }

    Loader {
        id: content

        x: {
            if (root.edge === "left")
                return root.width - width;
            if (root.edge === "right")
                return 0;
            return (root.width - width) / 2;
        }
        y: {
            if (root.edge === "top")
                return root.height - height;
            if (root.edge === "bottom")
                return 0;
            return (root.height - height) / 2;
        }

        width: item?.implicitWidth ?? 0
        height: item?.implicitHeight ?? 0

        visible: false
        active: true

        sourceComponent: Content {
            visibilities: root.visibilities
            state: root.dashState
        }
    }
}
