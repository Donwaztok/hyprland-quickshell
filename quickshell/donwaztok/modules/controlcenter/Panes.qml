pragma ComponentBehavior: Bound

import "bluetooth"
import "network"
import "audio"
import "appearance"
import "hyprland"
import "taskbar"
import "launcher"
import "dashboard"
import qs.components
import qs.services.shell
import qs.config
import qs.modules.controlcenter
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

ClippingRectangle {
    id: root

    required property Session session

    readonly property bool initialOpeningComplete: layout.initialOpeningComplete

    color: ControlCenterChrome.settingsContentBackdrop
    clip: true
    focus: false
    activeFocusOnTab: false

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: function (mouse) {
            root.focus = true;
            mouse.accepted = false;
        }
    }

    Connections {
        target: root.session

        function onActiveIndexChanged(): void {
            root.focus = true;
        }
    }

    StackLayout {
        id: layout

        anchors.fill: parent
        anchors.leftMargin: ControlCenterChrome.paneStackMargin
        anchors.rightMargin: ControlCenterChrome.paneStackMargin
        anchors.bottomMargin: ControlCenterChrome.paneStackMargin
        anchors.topMargin: ControlCenterChrome.paneStackMargin
        currentIndex: {
            const i = root.session.activeIndex;
            if (i >= 0 && i < PaneRegistry.count)
                return i;
            return 0;
        }

        property bool initialOpeningComplete: false

        Timer {
            id: initialOpeningTimer
            interval: Appearance.anim.durations.large
            running: true
            onTriggered: {
                layout.initialOpeningComplete = true;
            }
        }

        Repeater {
            model: PaneRegistry.count

            Pane {
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true

                paneIndex: index
                componentPath: PaneRegistry.getByIndex(index).component
            }
        }
    }

    component Pane: Item {
        id: pane

        required property int paneIndex
        required property string componentPath

        property bool hasBeenLoaded: false

        clip: true

        Loader {
            id: loader

            anchors.fill: parent
            clip: true
            active: root.session.activeIndex === pane.paneIndex

            function loadIfNeeded() {
                if (!active || item)
                    return;
                loader.setSource(pane.componentPath, {
                    "session": root.session
                });
            }

            Component.onCompleted: loadIfNeeded()

            onActiveChanged: {
                if (active && !pane.hasBeenLoaded)
                    pane.hasBeenLoaded = true;

                loadIfNeeded();
            }

            onItemChanged: {
                if (item)
                    pane.hasBeenLoaded = true;
            }
        }
    }
}
