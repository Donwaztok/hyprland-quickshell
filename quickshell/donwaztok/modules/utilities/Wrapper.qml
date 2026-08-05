pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property var visibilities
    required property Item sidebar
    required property Item popouts

    readonly property bool shouldBeActive: visibilities.sidebar || (visibilities.utilities && Config.utilities.enabled && !(visibilities.session && Config.session.enabled))
    readonly property real profilesExtraWidth: {
        if (!content.item?.audioProfilesOpen)
            return 0;
        return content.item.audioProfilesWidth + Appearance.spacing.normal;
    }

    visible: height > 0
    implicitHeight: (state === "visible" && content.item) ? (content.implicitHeight + Appearance.padding.large * 2) : 0
    implicitWidth: sidebar.visible ? sidebar.width : Config.utilities.sizes.width + profilesExtraWidth

    onShouldBeActiveChanged: {
        if (!shouldBeActive && content.item)
            content.item.audioProfilesOpen = false;
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    onStateChanged: {
        if (state === "visible" && timer.running) {
            timer.triggered();
            timer.stop();
        }
    }

    states: State {
        name: "visible"
        when: root.shouldBeActive
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

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
                property: "implicitHeight"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Timer {
        id: timer

        running: true
        interval: Appearance.anim.durations.extraLarge
        onTriggered: {
            content.active = Qt.binding(() => root.shouldBeActive || root.visible);
            content.visible = true;
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Appearance.padding.large

        visible: false
        active: true

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - Appearance.padding.large * 2
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }
}
