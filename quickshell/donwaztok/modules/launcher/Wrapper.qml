pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled
    property int contentHeight

    readonly property real maxHeight: {
        let max = screen.height * 0.55;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight * 0.5;
        return Math.min(max, root.availableHeight);
    }

    readonly property real availableHeight: {
        if (!parent)
            return screen.height;
        return Math.max(Config.launcher.sizes.searchBarHeight, parent.height - y);
    }

    property real contentOpacity: 0
    property real contentScale: 0.96

    onMaxHeightChanged: timer.start()
    onAvailableHeightChanged: timer.start()
    onYChanged: timer.start()

    function updateContentHeight(): void {
        if (content.status === Loader.Ready && content.item) {
            const cap = content.item.panelMaxHeight ?? root.maxHeight;
            root.contentHeight = Math.min(cap, content.item.implicitHeight);
        }
    }

    function requestSearchFocus(): void {
        if (!root.shouldBeActive || content.status !== Loader.Ready || !content.item)
            return;
        content.item.focusSearchField();
    }

    visible: height > 0
    implicitHeight: 0
    implicitWidth: content.implicitWidth

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            timer.stop();
            hideAnim.stop();
            contentOpacity = 0;
            contentScale = 0.96;
            showAnim.start();
        } else {
            showAnim.stop();
            hideAnim.start();
        }
    }

    SequentialAnimation {
        id: showAnim

        ParallelAnimation {
            Anim {
                target: root
                property: "implicitHeight"
                to: root.contentHeight
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
            Anim {
                target: root
                property: "contentOpacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
            Anim {
                target: root
                property: "contentScale"
                from: 0.96
                to: 1
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        ScriptAction {
            script: {
                root.contentOpacity = 1;
                root.contentScale = 1;
                root.implicitHeight = Qt.binding(() => content.implicitHeight);
                focusTimer.restart();
            }
        }
    }

    Timer {
        id: focusTimer

        interval: 50
        repeat: false
        onTriggered: root.requestSearchFocus()
    }

    SequentialAnimation {
        id: hideAnim

        ScriptAction {
            script: root.implicitHeight = root.implicitHeight
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "implicitHeight"
                to: 0
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
            Anim {
                target: root
                property: "contentOpacity"
                to: 0
                duration: Appearance.anim.durations.expressiveEffects
                easing.bezierCurve: Appearance.anim.curves.expressiveEffects
            }
            Anim {
                target: root
                property: "contentScale"
                to: 0.96
                duration: Appearance.anim.durations.expressiveEffects
                easing.bezierCurve: Appearance.anim.curves.expressiveEffects
            }
        }
        ScriptAction {
            script: {
                root.contentOpacity = 0;
                root.contentScale = 0.96;
            }
        }
    }

    Connections {
        target: Config.launcher

        function onEnabledChanged(): void {
            timer.start();
        }

        function onMaxShownChanged(): void {
            timer.start();
        }

        function onClipboardMaxShownChanged(): void {
            timer.start();
        }
    }

    Timer {
        id: timer

        interval: Appearance.anim.durations.extraLarge
        onRunningChanged: {
            if (running && !root.shouldBeActive) {
                content.visible = false;
                content.active = true;
            } else {
                root.contentHeight = Math.min(content.item?.panelMaxHeight ?? root.maxHeight, content.implicitHeight);
                content.active = Qt.binding(() => root.shouldBeActive || root.visible);
                content.visible = true;
            }
        }
    }

    // Explicit Component avoids "Cannot create delegate" with ComponentBehavior: Bound + inline sourceComponent.
    Component {
        id: launcherContentComponent

        Content {
            screen: root.screen
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
            availableHeight: root.availableHeight

            Component.onCompleted: root.updateContentHeight()
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        opacity: root.contentOpacity
        scale: root.contentScale
        transformOrigin: Item.Top

        visible: false
        active: false
        asynchronous: false
        sourceComponent: launcherContentComponent

        Component.onCompleted: timer.start()

        onLoaded: {
            root.updateContentHeight();
            if (root.shouldBeActive)
                focusTimer.restart();
        }

        onImplicitHeightChanged: root.updateContentHeight()
    }

    Connections {
        target: content.item

        enabled: content.status === Loader.Ready && content.item !== null

        function onImplicitHeightChanged(): void {
            root.updateContentHeight();
        }

        function onPanelMaxHeightChanged(): void {
            root.updateContentHeight();
        }

        function onAvailableHeightChanged(): void {
            root.updateContentHeight();
        }
    }
}
