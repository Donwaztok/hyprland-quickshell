import qs.services.shell
import qs
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    // Esc is primarily handled via Hyprland submap regionSelector; Exclusive
    // keeps an in-window fallback working when focus does arrive.
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // TODO: Ask: sidebar AI
    enum SnipAction { Copy, Edit, Search, CharRecognition }
    enum SelectionMode { RectCorners, Circle }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    signal dismiss()

    property string screenshotDir: Directories.screenshotTemp
    property color overlayColor: ColorUtils.transparentize(Colours.tPalette.m3scrim, 0.45)
    property color brightText: !Colours.light ? Colours.tPalette.m3onSurface : Colours.tPalette.m3surface
    property color brightSecondary: !Colours.light ? Colours.tPalette.m3secondary : Colours.tPalette.m3onSecondary
    property color brightTertiary: !Colours.light ? Colours.tPalette.m3tertiary : Qt.lighter(Colours.tPalette.m3primary)
    property color selectionBorderColor: ColorUtils.mix(brightText, brightSecondary, 0.5)
    property color selectionFillColor: ColorUtils.transparentize(Colours.tPalette.m3primary, 0.18)
    property color windowBorderColor: brightSecondary
    property color windowFillColor: ColorUtils.transparentize(windowBorderColor, 0.85)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: ColorUtils.transparentize(imageBorderColor, 0.85)
    property color onBorderColor: "#ff000000"
    readonly property var windows: [...HyprlandData.windowList].sort((a, b) => {
        // Sort floating=true windows before others
        if (a.floating === b.floating) return 0;
        return a.floating ? -1 : 1;
    })
    readonly property var layers: HyprlandData.layers
    readonly property real falsePositivePreventionRatio: 0.5

    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: hyprlandMonitor.scale
    readonly property real monitorOffsetX: hyprlandMonitor.x
    readonly property real monitorOffsetY: hyprlandMonitor.y
    property int activeWorkspaceId: hyprlandMonitor.activeWorkspace?.id ?? 0
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}`
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property list<var> mappedWindowRegions: root.windows
        .filter(w => w.workspace.id === root.activeWorkspaceId)
        .map(window => {
            return {
                at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
                size: [window.size[0], window.size[1]],
                class: window.class,
                title: window.title,
            };
        })
        .filter(w => w.size[0] > 1 && w.size[1] > 1
            && w.at[0] < root.screen.width && w.at[1] < root.screen.height
            && (w.at[0] + w.size[0]) > 0 && (w.at[1] + w.size[1]) > 0)

    // Layer filter is only for normal hover chrome; Ctrl pick uses all mapped windows.
    readonly property list<var> windowRegions: RegionFunctions.filterWindowRegionsByLayers(
        root.mappedWindowRegions,
        root.layerRegions
    )
    readonly property list<var> layerRegions: {
        const layersOfThisMonitor = root.layers[root.hyprlandMonitor.name]
        const topLayers = layersOfThisMonitor?.levels["2"]
        if (!topLayers) return [];
        // Ignore shell chrome (fullscreen drawers/overlays would hide every window).
        const nonShellTopLayers = topLayers
            .filter(layer => {
                const ns = layer.namespace ?? "";
                return !(ns.includes(":bar")
                    || ns.includes(":verticalBar")
                    || ns.includes(":dock")
                    || ns.includes("drawers")
                    || ns.includes("donwaztok-")
                    || ns.startsWith("quickshell"));
            })
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonShellTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: Config.options.regionSelector.targetRegions.windows && !isCircleSelection
    property bool enableLayerRegions: Config.options.regionSelector.targetRegions.layers && !isCircleSelection
    property bool enableContentRegions: Config.options.regionSelector.targetRegions.content
    property real targetRegionOpacity: Config.options.regionSelector.targetRegions.opacity
    property bool contentRegionOpacity: Config.options.regionSelector.targetRegions.contentRegionOpacity

    // Hold Ctrl to pick a whole window. Synced via Keys + mouse modifiers into GlobalStates
    // so both monitors stay in sync (Hyprland must not bind Ctrl in the snip submap).
    readonly property bool ctrlHeld: GlobalStates.regionSelectorCtrlHeld
    readonly property bool windowPickMode: ctrlHeld && !isCircleSelection

    function setCtrlHeld(held) {
        if (GlobalStates.regionSelectorCtrlHeld === held)
            return;
        GlobalStates.regionSelectorCtrlHeld = held;
    }

    onCtrlHeldChanged: {
        if (mouseArea)
            root.updateTargetedRegion(mouseArea.mouseX, mouseArea.mouseY);
    }

    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted(padding) {
        const p = (padding === undefined || padding === null)
            ? Config.options.regionSelector.targetRegions.selectionPadding
            : padding;
        root.regionX = root.targetedRegionX - p;
        root.regionY = root.targetedRegionY - p;
        root.regionWidth = root.targetedRegionWidth + p * 2;
        root.regionHeight = root.targetedRegionHeight + p * 2;
    }

    function hitTestRegion(regions, x, y) {
        // Prefer later entries (closer to top of floating-first list).
        for (let i = regions.length - 1; i >= 0; --i) {
            const region = regions[i];
            if (region.at[0] <= x && x <= region.at[0] + region.size[0]
                && region.at[1] <= y && y <= region.at[1] + region.size[1])
                return region;
        }
        return undefined;
    }

    function applyTargetedRegion(region) {
        if (!region) {
            root.targetedRegionX = -1;
            root.targetedRegionY = -1;
            root.targetedRegionWidth = 0;
            root.targetedRegionHeight = 0;
            return false;
        }
        root.targetedRegionX = region.at[0];
        root.targetedRegionY = region.at[1];
        root.targetedRegionWidth = region.size[0];
        root.targetedRegionHeight = region.size[1];
        return true;
    }

    function updateTargetedRegion(x, y) {
        // Ctrl = window pick: only windows, never content/layer regions.
        if (root.windowPickMode) {
            root.applyTargetedRegion(root.hitTestRegion(root.mappedWindowRegions, x, y));
            return;
        }

        if (root.applyTargetedRegion(root.hitTestRegion(root.imageRegions, x, y)))
            return;
        if (root.enableLayerRegions && root.applyTargetedRegion(root.hitTestRegion(root.layerRegions, x, y)))
            return;
        if (root.enableWindowRegions && root.applyTargetedRegion(root.hitTestRegion(root.windowRegions, x, y)))
            return;

        root.applyTargetedRegion(null);
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    TempScreenshotProcess {
        id: screenshotProc
        running: true
        screen: root.screen
        screenshotDir: root.screenshotDir
        screenshotPath: root.screenshotPath
        onExited: (exitCode, exitStatus) => {
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = true;
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        root.visible = true;
    }
    onVisibleChanged: {
        if (visible)
            captureHost.forceActiveFocus();
    }

    Process {
        id: imageDetectionProcess
        command: ["bash", "-c", `${Directories.scriptPath}/images/find-regions-venv.sh `
            + `--hyprctl `
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' `
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} `
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                const raw = (imageDimensionCollector.text ?? "").trim();
                let parsed = [];
                if (raw.length > 0) {
                    try {
                        parsed = JSON.parse(raw);
                    } catch (e) {
                        console.warn("[RegionSelection] find-regions stdout is not valid JSON:", raw.slice(0, 200));
                    }
                }
                imageRegions = RegionFunctions.filterImageRegions(parsed, root.windowRegions);
            }
        }
    }

    function getScreenshotAction() {
        switch(root.action) {
            case RegionSelection.SnipAction.Copy:
                return ScreenshotAction.Action.Copy;
            case RegionSelection.SnipAction.Edit:
                return ScreenshotAction.Action.Edit;
            case RegionSelection.SnipAction.Search:
                return ScreenshotAction.Action.Search;
            case RegionSelection.SnipAction.CharRecognition:
                return ScreenshotAction.Action.CharRecognition;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                root.dismiss();
                return;
        }
    }

    function snip(cornerRadius = 0) {
        // Validity check
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            console.warn("[Region Selector] Invalid region size, skipping snip.");
            root.dismiss();
            return;
        }

        // Clamp region to screen bounds
        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        // Adjust action
        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        const screenshotDir = Config.options.screenSnip.savePath !== "" ? //
            Config.options.screenSnip.savePath : "";
        var screenshotAction = root.getScreenshotAction();
        const command = ScreenshotAction.getCommand(
            root.regionX * root.monitorScale, //
            root.regionY * root.monitorScale, //
            root.regionWidth * root.monitorScale,//
            root.regionHeight * root.monitorScale, //
            root.screenshotPath, //
            screenshotAction, //
            screenshotDir,
            Math.max(0, cornerRadius) * root.monitorScale
        )
        snipProc.command = command;

        // Image post-processing
        snipProc.startDetached();
        root.dismiss();
    }

    Process {
        id: snipProc
    }

    Item {
        id: captureHost
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.dismiss();
                return;
            }
            if (event.key === Qt.Key_Control) {
                event.accepted = true;
                root.setCtrlHeld(true);
            }
        }
        Keys.onReleased: (event) => {
            if (event.key === Qt.Key_Control) {
                event.accepted = true;
                root.setCtrlHeld(false);
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.visible
            onActivated: root.dismiss()
        }

        Image {
            id: frozenCapture
            anchors.fill: parent
            fillMode: Image.Stretch
            cache: false
            asynchronous: true
            source: root.preparationDone ? Qt.resolvedUrl("file://" + root.screenshotPath) : ""
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: root.windowPickMode ? Qt.PointingHandCursor : Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            function syncCtrlFromMouse(mouse) {
                // Only promote to held from mouse mods. Clearing is handled by
                // Keys/Hyprland release so a stale pointer event cannot drop Ctrl.
                if (mouse.modifiers & Qt.ControlModifier)
                    root.setCtrlHeld(true);
            }

            function resetDragState() {
                root.dragging = false;
                root.dragDiffX = 0;
                root.dragDiffY = 0;
                root.points = [];
                root.draggingX = root.dragStartX;
                root.draggingY = root.dragStartY;
            }

            // Controls
            onPressed: (mouse) => {
                mouseArea.syncCtrlFromMouse(mouse);
                root.dragStartX = mouse.x;
                root.dragStartY = mouse.y;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragging = true;
                root.mouseButton = mouse.button;
                root.points = [];
                root.updateTargetedRegion(mouse.x, mouse.y);
            }
            onReleased: (mouse) => {
                mouseArea.syncCtrlFromMouse(mouse);
                root.updateTargetedRegion(mouse.x, mouse.y);

                // Ctrl + click/drag: capture the highlighted window only.
                if (root.windowPickMode) {
                    if (root.targetedRegionValid()) {
                        root.setRegionToTargeted(0);
                        // Match Hyprland decoration:rounding so corners are transparent PNG.
                        root.snip(Appearance.rounding.windowRounding);
                    } else {
                        mouseArea.resetDragState();
                    }
                    return;
                }

                // Detect if it was a click -> Try to select targeted region
                if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                    if (root.targetedRegionValid()) {
                        root.setRegionToTargeted();
                    }
                }
                // Circle dragging?
                else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                    const padding = Config.options.regionSelector.circle.padding + Config.options.regionSelector.circle.strokeWidth / 2;
                    const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                    const maxX = Math.max(...dragPoints.map(p => p.x));
                    const minX = Math.min(...dragPoints.map(p => p.x));
                    const maxY = Math.max(...dragPoints.map(p => p.y));
                    const minY = Math.min(...dragPoints.map(p => p.y));
                    root.regionX = minX - padding;
                    root.regionY = minY - padding;
                    root.regionWidth = maxX - minX + padding * 2;
                    root.regionHeight = maxY - minY + padding * 2;
                }
                root.snip();
            }
            onPositionChanged: (mouse) => {
                mouseArea.syncCtrlFromMouse(mouse);
                root.updateTargetedRegion(mouse.x, mouse.y);
                if (!root.dragging || root.windowPickMode)
                    return;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragDiffX = mouse.x - root.dragStartX;
                root.dragDiffY = mouse.y - root.dragStartY;
                root.points.push({ x: mouse.x, y: mouse.y });
            }

            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.RectCorners && !root.windowPickMode
                sourceComponent: RectCornersSelectionDetails {
                    regionX: root.regionX
                    regionY: root.regionY
                    regionWidth: root.regionWidth
                    regionHeight: root.regionHeight
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                }
            }

            // Dim the desktop while picking a window; hole follows the target.
            Loader {
                z: 1
                anchors.fill: parent
                active: root.windowPickMode
                sourceComponent: RectCornersSelectionDetails {
                    regionX: root.targetedRegionValid() ? root.targetedRegionX : mouseArea.mouseX
                    regionY: root.targetedRegionValid() ? root.targetedRegionY : mouseArea.mouseY
                    regionWidth: root.targetedRegionValid() ? root.targetedRegionWidth : 0
                    regionHeight: root.targetedRegionValid() ? root.targetedRegionHeight : 0
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.windowBorderColor
                    overlayColor: root.overlayColor
                    showAimLines: false
                }
            }

            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.Circle && !root.windowPickMode
                sourceComponent: CircleSelectionDetails {
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                    points: root.points
                }
            }

            CursorGuide {
                z: 9999
                x: root.windowPickMode
                    ? mouseArea.mouseX
                    : (root.dragging ? root.regionX + root.regionWidth : mouseArea.mouseX)
                y: root.windowPickMode
                    ? mouseArea.mouseY
                    : (root.dragging ? root.regionY + root.regionHeight : mouseArea.mouseY)
                action: root.action
                selectionMode: root.selectionMode
                windowPickMode: root.windowPickMode
            }

            // Window regions
            Repeater {
                model: ScriptModel {
                    values: root.windowPickMode
                        ? root.mappedWindowRegions
                        : (root.enableWindowRegions ? root.windowRegions : [])
                }
                delegate: TargetRegion {
                    z: 2
                    required property var modelData
                    clientDimensions: modelData
                    showIcon: true
                    showLabel: root.windowPickMode || Config.options.regionSelector.targetRegions.showLabel
                    targeted: !root.draggedAway &&
                        (root.targetedRegionX === modelData.at[0]
                        && root.targetedRegionY === modelData.at[1]
                        && root.targetedRegionWidth === modelData.size[0]
                        && root.targetedRegionHeight === modelData.size[1])

                    opacity: {
                        if (root.windowPickMode)
                            return targeted ? 1 : 0.45;
                        return root.draggedAway ? 0 : root.targetRegionOpacity;
                    }
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    borderWidth: targeted ? (root.windowPickMode ? 5 : 4) : 2
                    text: `${modelData.class}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Layer regions
            Repeater {
                model: ScriptModel {
                    values: (!root.windowPickMode && root.enableLayerRegions) ? root.layerRegions : []
                }
                delegate: TargetRegion {
                    z: 3
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway &&
                        (root.targetedRegionX === modelData.at[0]
                        && root.targetedRegionY === modelData.at[1]
                        && root.targetedRegionWidth === modelData.size[0]
                        && root.targetedRegionHeight === modelData.size[1])

                    opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    text: `${modelData.namespace}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Content regions
            Repeater {
                model: ScriptModel {
                    values: (!root.windowPickMode && root.enableContentRegions) ? root.imageRegions : []
                }
                delegate: TargetRegion {
                    z: 4
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway &&
                        (root.targetedRegionX === modelData.at[0]
                        && root.targetedRegionY === modelData.at[1]
                        && root.targetedRegionWidth === modelData.size[0]
                        && root.targetedRegionHeight === modelData.size[1])

                    opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                    borderColor: root.imageBorderColor
                    fillColor: targeted ? root.imageFillColor : "transparent"
                    text: qsTr("Content region")
                }
            }

            // Controls
            Row {
                id: regionSelectionControls
                z: 10
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: -height
                }
                opacity: 0
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (!visible) return;
                        regionSelectionControls.anchors.bottomMargin = 8;
                        regionSelectionControls.opacity = 1;
                    }
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on anchors.bottomMargin {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                spacing: 6

                OptionsToolbar {
                    Synchronizer on action {
                        property alias source: root.action
                    }
                    Synchronizer on selectionMode {
                        property alias source: root.selectionMode
                    }
                    onDismiss: root.dismiss();
                }
                Item {
                    anchors {
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: closeFab.implicitWidth
                    implicitHeight: closeFab.implicitHeight
                    StyledRectangularShadow {
                        target: closeFab
                        radius: closeFab.buttonRadius
                    }
                    FloatingActionButton {
                        id: closeFab
                        baseSize: 48
                        iconText: "close"
                        onClicked: root.dismiss();
                        StyledToolTip {
                            text: qsTr("Close")
                        }
                        colBackground: Colours.tPalette.m3primary
                        colBackgroundHover: ColorUtils.mix(Colours.tPalette.m3primary, Colours.tPalette.m3onPrimary, 0.88)
                        colRipple: ColorUtils.mix(Colours.tPalette.m3primary, Colours.tPalette.m3onPrimary, 0.75)
                        colOnBackground: Colours.tPalette.m3onPrimary
                    }
                }
            }

        }
    }
}
