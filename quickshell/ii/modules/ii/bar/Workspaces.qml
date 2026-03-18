import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    // Optional overrides for reuse outside ii bar (e.g. caelestia bar)
    property var screenOverride: null
    property var overrideActiveColor: undefined
    property var overrideInactiveColor: undefined
    property bool borderless: Config.options.bar.borderless
    readonly property var resolvedScreen: root.screenOverride ?? root.QsWindow.window?.screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.resolvedScreen) ?? Hyprland.focusedMonitor
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int effectiveActiveWorkspaceId: root.monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1
    readonly property color activeIndicatorColor: root.overrideActiveColor ?? Appearance.colors.colPrimary
    readonly property color inactiveIndicatorColor: root.overrideInactiveColor ?? Appearance.m3colors.m3onSurfaceVariant

    readonly property string workspaceStyle: Config.options.bar.workspaces.style || "gnome"
    readonly property bool isGnomeStyle: root.workspaceStyle === "gnome"

    readonly property int workspacesShown: Math.max(1, Config.options.bar.workspaces.shown)
    readonly property bool isDynamicMode: root.isGnomeStyle && (Config.options.bar.workspaces.shown === 0)

    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / Math.max(1, root.workspacesShown))
    readonly property int workspaceIndexInGroup: root.workspacesShown > 0 ? ((effectiveActiveWorkspaceId - 1) % root.workspacesShown) : 0

    property var openWorkspaceIds: [1]
    property int activeIndex: 0
    property list<bool> workspaceOccupied: []

    property int widgetPadding: 4
    property int workspaceButtonWidth: (Config.options.bar.workspaces.workspaceButtonWidth ?? 11)
    property int activeSlotWidth: (Config.options.bar.workspaces.activeSlotWidth ?? 24)
    property real activeWorkspaceMargin: 1
    property real dashWidthFactor: (Config.options.bar.workspaces.dashWidthFactor ?? 2.0)
    property real dashMargin: (Config.options.bar.workspaces.dashMargin ?? 1)
    readonly property real indicatorSize: (Config.options.bar.workspaces.indicatorSize ?? Config.options.bar.workspaces.dotSize ?? Config.options.bar.workspaces.pillHeight ?? 6)
    readonly property real pillWidth: (root.activeSlotWidth - root.dashMargin * 2) * root.dashWidthFactor
    readonly property real dotSize: root.indicatorSize
    readonly property real pillHeight: root.indicatorSize
    readonly property real maxDashWidth: root.activeSlotWidth - root.dashMargin * 2
    property int classicSlotWidth: Config.options.bar.workspaces.classicSlotWidth ?? 26

    function updateOpenWorkspaces() {
        var monName = root.monitor?.name
        if (!monName) {
            root.openWorkspaceIds = [1]
            return
        }
        var list = Hyprland.workspaces.values.filter(function(ws) {
            return ws.monitor && ws.monitor.name === monName && ws.id >= 1 && ws.id < 1000000
        })
        list.sort(function(a, b) { return a.id - b.id })
        root.openWorkspaceIds = list.map(function(ws) { return ws.id })
        if (root.openWorkspaceIds.length === 0)
            root.openWorkspaceIds = [1]
    }

    function syncActiveFromHyprland() {
        if (root.isGnomeStyle) {
            root.activeIndex = root.openWorkspaceIds.indexOf(root.effectiveActiveWorkspaceId)
            if (root.activeIndex < 0) root.activeIndex = 0
        }
    }

    function updateWorkspaceOccupied() {
        if (!root.isGnomeStyle) {
            root.workspaceOccupied = Array.from({ length: root.workspacesShown }, function(_, i) {
                return Hyprland.workspaces.values.some(function(ws) {
                    return ws.id === root.workspaceGroup * root.workspacesShown + i + 1
                })
            })
        }
    }

    function updateActiveIndex() {
        root.activeIndex = root.openWorkspaceIds.indexOf(root.effectiveActiveWorkspaceId)
        if (root.activeIndex < 0) root.activeIndex = 0
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateOpenWorkspaces()
            syncActiveFromHyprland()
            if (!root.isGnomeStyle) updateWorkspaceOccupied()
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            updateOpenWorkspaces()
            syncActiveFromHyprland()
        }
    }
    onOpenWorkspaceIdsChanged: {
        updateActiveIndex()
        if (root.isDynamicMode) updateSlotWorkspaceIds()
    }

    readonly property int openCount: openWorkspaceIds.length
    property var slotWorkspaceIds: [1]

    function updateSlotWorkspaceIds() {
        if (root.isDynamicMode) {
            root.slotWorkspaceIds = root.openWorkspaceIds.length ? root.openWorkspaceIds : [1]
        } else {
            var n = root.workspacesShown
            var group = root.workspaceGroup
            var arr = []
            for (var i = 0; i < n; i++)
                arr.push(group * n + i + 1)
            root.slotWorkspaceIds = arr
        }
    }

    readonly property int slotCount: root.isDynamicMode ? Math.max(1, root.openCount) : root.workspacesShown
    readonly property int dashIndex: root.isDynamicMode ? root.activeIndex : root.workspaceIndexInGroup

    Component.onCompleted: {
        updateOpenWorkspaces()
        syncActiveFromHyprland()
        updateSlotWorkspaceIds()
        if (!root.isGnomeStyle) updateWorkspaceOccupied()
    }
    onIsDynamicModeChanged: updateSlotWorkspaceIds()
    onWorkspaceGroupChanged: {
        if (!root.isDynamicMode) updateSlotWorkspaceIds()
        if (!root.isGnomeStyle) updateWorkspaceOccupied()
    }
    onWorkspacesShownChanged: updateSlotWorkspaceIds()

    readonly property real totalWidth: root.vertical ? root.workspaceButtonWidth : (root.isGnomeStyle ? ((Math.max(1, root.slotCount) - 1) * root.workspaceButtonWidth + root.activeSlotWidth) : (root.workspacesShown * root.classicSlotWidth))
    readonly property real totalHeight: root.vertical ? (root.isGnomeStyle ? ((Math.max(1, root.slotCount) - 1) * root.workspaceButtonWidth + root.activeSlotWidth) : (root.workspacesShown * root.classicSlotWidth)) : root.workspaceButtonWidth
    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : root.totalWidth
    implicitHeight: root.vertical ? root.totalHeight : Appearance.sizes.barHeight

    // Scroll to switch workspaces
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: (event) => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            }
        }
    }

    property bool showNumbers: false
    Timer {
        id: showNumbersTimer
        interval: Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100
        repeat: false
        onTriggered: root.showNumbers = true
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return
            if (GlobalStates.superDown) showNumbersTimer.restart()
            else { showNumbersTimer.stop(); root.showNumbers = false }
        }
        function onSuperReleaseMightTriggerChanged() { showNumbersTimer.stop() }
    }

    // --- GNOME style ---
    Item {
        visible: root.isGnomeStyle
        anchors.fill: parent

        Item {
            id: gnomeTrack
            anchors.centerIn: parent
            width: root.vertical ? root.totalHeight : root.totalWidth
            height: root.workspaceButtonWidth
            rotation: root.vertical ? 90 : 0

            Row {
                z: 1
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: root.slotWorkspaceIds

                    Item {
                        required property int index
                        required property var modelData
                        width: root.dashIndex === index ? root.activeSlotWidth : root.workspaceButtonWidth
                        height: root.workspaceButtonWidth
                        property int workspaceValue: Number(modelData) || 1
                        property bool isOpen: root.openWorkspaceIds.indexOf(workspaceValue) >= 0
                        property bool isActive: root.dashIndex === index
                        property bool showDot: !isActive && (root.isDynamicMode || isOpen)

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.isActive ? Math.min(root.maxDashWidth, Math.max(root.pillHeight, root.pillWidth - root.dashMargin * 2)) : (parent.showDot ? root.dotSize : 0)
                            height: parent.isActive ? root.pillHeight : (parent.showDot ? root.dotSize : 0)
                            radius: parent.isActive ? (root.pillHeight / 2) : (parent.showDot ? root.dotSize / 2 : 0)
                            color: parent.isActive ? root.activeIndicatorColor : root.inactiveIndicatorColor
                            opacity: (parent.isActive || parent.showDot) ? (parent.isActive ? 1 : 0.7) : 0
                            visible: opacity > 0

                            Behavior on width {
                                NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
                            }
                            Behavior on height {
                                NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
                            }
                            Behavior on radius {
                                NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 180 }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        Behavior on width {
                            NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: Hyprland.dispatch(`workspace ${parent.workspaceValue}`)
                        }
                    }
                }
            }
        }
    }

    // --- Classic style ---
    Item {
        visible: !root.isGnomeStyle
        anchors.fill: parent
        Grid {
            z: 1
            anchors.centerIn: parent
            rowSpacing: 0
            columnSpacing: 0
            columns: root.vertical ? 1 : root.workspacesShown
            rows: root.vertical ? root.workspacesShown : 1
            Repeater {
                model: root.workspacesShown
                Rectangle {
                    required property int index
                    width: root.classicSlotWidth
                    height: root.classicSlotWidth
                    radius: width / 2
                    color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                    opacity: (root.workspaceOccupied[index] && root.effectiveActiveWorkspaceId !== (root.workspaceGroup * root.workspacesShown + index + 1)) ? 1 : 0
                    Behavior on opacity { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
                }
            }
        }
        Rectangle {
            z: 2
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
            anchors.verticalCenter: parent.verticalCenter
            AnimatedTabIndexPair { id: classicIdx; index: root.workspaceIndexInGroup }
            property real slotW: root.classicSlotWidth - root.activeWorkspaceMargin * 2
            property real pos: Math.min(classicIdx.idx1, classicIdx.idx2) * root.classicSlotWidth + root.activeWorkspaceMargin
            x: root.vertical ? (root.classicSlotWidth - slotW) / 2 : pos
            y: root.vertical ? pos : (parent.height - slotW) / 2
            width: slotW
            height: slotW
        }
        Grid {
            z: 3
            anchors.fill: parent
            columns: root.vertical ? 1 : root.workspacesShown
            rows: root.vertical ? root.workspacesShown : 1
            columnSpacing: 0
            rowSpacing: 0
            Repeater {
                model: root.workspacesShown
                Button {
                    required property int index
                    property int workspaceValue: root.workspaceGroup * root.workspacesShown + index + 1
                    width: root.vertical ? undefined : root.classicSlotWidth
                    height: root.vertical ? root.classicSlotWidth : undefined
                    onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                    background: Item {
                        id: classicCell
                        width: root.classicSlotWidth
                        height: root.classicSlotWidth
                        property int wsValue: parent.workspaceValue
                        property int wsIndex: index
                        property var biggestWindow: HyprlandData.biggestWindowForWorkspace(wsValue)
                        property var mainAppIconSource: Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.class), "image-missing")
                        StyledText {
                            opacity: (root.showNumbers || Config.options.bar.workspaces.alwaysShowNumbers || (Config.options.bar.workspaces.showAppIcons && classicCell.biggestWindow && root.showNumbers) || (root.showNumbers && !Config.options.bar.workspaces.showAppIcons)) ? 1 : 0
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.barPixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                            font.family: Config.options?.bar.workspaces.useNerdFont ? Appearance.font.family.iconNerd : "sans-serif"
                            text: (Config.options?.bar.workspaces.numberMap || [])[classicCell.wsValue - 1] || classicCell.wsValue
                            color: root.effectiveActiveWorkspaceId === classicCell.wsValue ? Appearance.m3colors.m3onPrimary : (root.workspaceOccupied[classicCell.wsIndex] ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1Inactive)
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: root.classicSlotWidth * 0.18
                            height: width
                            radius: width / 2
                            color: root.effectiveActiveWorkspaceId === classicCell.wsValue ? Appearance.m3colors.m3onPrimary : (root.workspaceOccupied[classicCell.wsIndex] ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1Inactive)
                            opacity: (Config.options?.bar.workspaces.alwaysShowNumbers || root.showNumbers || (Config.options?.bar.workspaces.showAppIcons && classicCell.biggestWindow)) ? 0 : 1
                        }
                        IconImage {
                            visible: Config.options.bar.workspaces.showAppIcons && classicCell.biggestWindow
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            source: classicCell.mainAppIconSource
                            width: root.classicSlotWidth * 0.69
                            height: width
                        }
                    }
                }
            }
        }
    }
}
