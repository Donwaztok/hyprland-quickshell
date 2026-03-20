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
    // Do not use children.find(c => c.active): during detach, the bar loader can
    // still be active=true while fading out but detached loaders are already active,
    // so find() returns the wrong item and implicitHeight collapses (Shape gap bug).
    // While detached, also use Config fallbacks so size is never 0 before Loader.item exists,
    // and disable implicit size Behaviors so height does not lag behind the real content.
    readonly property real detachedCcHeight: screen.height * Config.controlCenter.sizes.heightMult
    readonly property real detachedCcWidth: detachedCcHeight * Config.controlCenter.sizes.ratio
    readonly property real nonAnimWidth: detachedMode === "any"
        ? Math.max(detachedCcWidth, detachedLoader.item?.implicitWidth ?? detachedLoader.implicitWidth ?? 0)
        : detachedMode === "winfo"
            ? Math.max(1, winfoLoader.item?.implicitWidth ?? winfoLoader.implicitWidth ?? 0)
            : (hasCurrent ? (barPopoutsLoader.implicitWidth ?? 0) : 0)
    readonly property real nonAnimHeight: detachedMode === "any"
        ? Math.max(detachedCcHeight, detachedLoader.item?.implicitHeight ?? detachedLoader.implicitHeight ?? 0)
        : detachedMode === "winfo"
            ? Math.max(1, winfoLoader.item?.implicitHeight ?? winfoLoader.implicitHeight ?? 0)
            : (hasCurrent ? (barPopoutsLoader.implicitHeight ?? 0) : 0)
    readonly property Item current: barPopoutsLoader.item?.current ?? null

    property string currentName
    property real currentCenter
    property bool hasCurrent

    property string detachedMode
    property string queuedMode
    readonly property bool isDetached: detachedMode.length > 0

    property int animLength: Appearance.anim.durations.normal
    property list<real> animCurve: Appearance.anim.curves.emphasized

    // Ignores the first HyprlandFocusGrab clear right after detach (utilities collapse / mask update can spuriously clear).
    property bool suppressDetachedGrabClear: false

    Timer {
        id: detachedGrabClearTimer
        interval: 180
        repeat: false
        onTriggered: root.suppressDetachedGrabClear = false
    }

    function detach(mode: string): void {
        animLength = Appearance.anim.durations.large;
        suppressDetachedGrabClear = true;
        detachedGrabClearTimer.restart();
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

    // Detached surface: drawn here so it always matches Wrapper bounds (global Shape can desync).
    Rectangle {
        z: -1
        anchors.fill: parent
        visible: root.isDetached
        radius: Config.border.rounding
        color: Colours.palette.m3surface

        Behavior on color {
            CAnim {}
        }
    }

    focus: hasCurrent
    Keys.onEscapePressed: {
        // Forward escape to password popout if active, otherwise close
        if (currentName === "wirelesspassword" && barPopoutsLoader.item) {
            const passwordPopout = barPopoutsLoader.item.children.find(c => c.name === "wirelesspassword");
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
        onCleared: {
            if (root.suppressDetachedGrabClear)
                return;
            root.close();
        }
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
        id: barPopoutsLoader

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        sourceComponent: Content {
            wrapper: root
        }
    }

    Comp {
        id: winfoLoader

        shouldBeActive: root.detachedMode === "winfo"
        anchors.centerIn: parent

        sourceComponent: WindowInfo {
            screen: root.screen
            client: Hypr.activeToplevel
        }
    }

    Comp {
        id: detachedLoader

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
        enabled: !root.isDetached

        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.implicitWidth > 0 && !root.isDetached

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
