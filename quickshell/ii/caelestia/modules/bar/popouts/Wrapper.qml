pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import caelestia.modules.windowinfo
import caelestia.modules.controlcenter
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    required property ShellScreen screen

    // Keep geometry while a loader is still active (e.g. fade-out transition),
    // but collapse completely when no popout is active anymore.
    readonly property Item activeComp: children.find(c => c.active) ?? null
    readonly property real nonAnimWidth: activeComp?.implicitWidth ?? 0
    readonly property real nonAnimHeight: activeComp?.implicitHeight ?? 0
    readonly property Item current: content.item?.current ?? null

    property string currentName
    property real currentCenter
    property bool hasCurrent

    property string detachedMode
    property string queuedMode
    readonly property bool isDetached: detachedMode.length > 0

    property int animLength: Appearance.anim.durations.normal
    property list<real> animCurve: Appearance.anim.curves.emphasized

    function detach(mode: string): void {
        animLength = Appearance.anim.durations.large;
        if (mode === "winfo") {
            detachedMode = mode;
        } else {
            queuedMode = mode;
            detachedMode = "any";
        }
        focus = true;
    }

    function close(): void {
        hasCurrent = false;
        animCurve = Appearance.anim.curves.emphasizedAccel;
        animLength = Appearance.anim.durations.normal;
        detachedMode = "";
        animCurve = Appearance.anim.curves.emphasized;
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    focus: hasCurrent
    Keys.onEscapePressed: {
        // Forward escape to password popout if active, otherwise close
        if (currentName === "wirelesspassword" && content.item) {
            const passwordPopout = content.item.children.find(c => c.name === "wirelesspassword");
            if (passwordPopout && passwordPopout.item) {
                passwordPopout.item.closeDialog();
                return;
            }
        }
        close();
    }

    Keys.onPressed: event => {
        // Don't intercept keys when password popout is active - let it handle them
        if (currentName === "wirelesspassword") {
            event.accepted = false;
        }
    }

    HyprlandFocusGrab {
        active: root.isDetached
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    Binding {
        when: root.isDetached

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Binding {
        when: root.hasCurrent && root.currentName === "wirelesspassword"

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Comp {
        id: content

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        sourceComponent: Content {
            wrapper: root
        }
    }

    Comp {
        shouldBeActive: root.detachedMode === "winfo"
        anchors.centerIn: parent

        sourceComponent: WindowInfo {
            screen: root.screen
            client: Hypr.activeToplevel
        }
    }

    Comp {
        shouldBeActive: root.detachedMode === "any"
        anchors.centerIn: parent

        sourceComponent: ControlCenter {
            screen: root.screen
            active: root.queuedMode

            function close(): void {
                root.close();
            }
        }
    }

    Behavior on x {
        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on y {
        enabled: root.implicitWidth > 0

        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.implicitWidth > 0

        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    component Comp: Loader {
        id: comp

        property bool shouldBeActive

        active: false
        opacity: 0

        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
