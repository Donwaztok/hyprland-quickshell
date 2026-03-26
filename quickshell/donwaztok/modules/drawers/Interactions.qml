import qs.components.controls
import qs.config
import qs.modules.bar.popouts as BarPopouts
import Quickshell
import QtQuick

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property PersistentProperties visibilities
    required property Panels panels
    required property Item bar

    property point dragStart
    property bool dashboardShortcutActive
    property bool utilitiesShortcutActive

    function contentLeft(): real { return bar.leftMargin; }
    function contentTop(): real { return bar.topMargin; }

    function inBarArea(x: real, y: real): bool {
        return (bar.leftMargin > 0 && x < bar.leftMargin) || (bar.rightMargin > 0 && x >= width - bar.rightMargin)
            || (bar.topMargin > 0 && y < bar.topMargin) || (bar.bottomMargin > 0 && y >= height - bar.bottomMargin);
    }

    function barCoord(x: real, y: real): real {
        if (bar.leftMargin > 0 || bar.rightMargin > 0)
            return y;
        return x;
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = Config.border.thickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = contentLeft() + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < contentLeft() + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > contentLeft() + panel.x && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        return y < Config.border.thickness + panel.y + panel.height && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real): bool {
        let ph = Math.max(panel.height, panel.implicitHeight);
        if (visibilities.launcher && panel === panels.launcher) {
            const ch = panels.launcher.contentHeight ?? 0;
            ph = Math.max(ph, ch);
        }
        return y > root.height - Config.border.thickness - ph - Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (inBarArea(event.x, event.y)) {
            bar.handleWheel(barCoord(event.x, event.y), event.angleDelta);
        }
    }

    anchors.fill: parent
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            if (!dashboardShortcutActive)
                visibilities.dashboard = false;

            if (!utilitiesShortcutActive)
                visibilities.utilities = false;

            if (!popouts.currentName.startsWith("traymenu") || (popouts.current?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (!visibilities.bar && Config.bar.showOnHover && inBarArea(x, y))
            bar.isHovered = true;

        if (pressed && inBarArea(dragStart.x, dragStart.y)) {
            const dragTowardContent = (bar.leftMargin > 0 && dragX > 0) || (bar.rightMargin > 0 && dragX < 0) || (bar.topMargin > 0 && dragY > 0) || (bar.bottomMargin > 0 && dragY < 0);
            const dragTowardBar = (bar.leftMargin > 0 && dragX < 0) || (bar.rightMargin > 0 && dragX > 0) || (bar.topMargin > 0 && dragY < 0) || (bar.bottomMargin > 0 && dragY > 0);
            const dragDist = bar.leftMargin > 0 || bar.rightMargin > 0 ? Math.abs(dragX) : Math.abs(dragY);
            if (dragTowardContent && dragDist > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragTowardBar && dragDist > Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        if (panels.sidebar.width === 0) {
            const showSidebar = pressed && dragStart.x > contentLeft() + panels.sidebar.x;

            if (pressed && inRightPanel(panels.session, dragStart.x, dragStart.y) && withinPanelHeight(panels.session, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;

                if (showSidebar && panels.session.width >= panels.session.nonAnimWidth && dragX < -Config.sidebar.dragThreshold)
                    visibilities.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                visibilities.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width;

            if (pressed && outOfSidebar && inRightPanel(panels.session, dragStart.x, dragStart.y) && withinPanelHeight(panels.session, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;
            }

            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                visibilities.sidebar = false;
        }

        if (Config.launcher.showOnHover) {
            if (!visibilities.launcher && inBottomPanel(panels.launcher, x, y))
                visibilities.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                visibilities.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                visibilities.launcher = false;
        }

        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);

        if (!dashboardShortcutActive) {
            visibilities.dashboard = showDashboard;
        } else if (showDashboard) {
            dashboardShortcutActive = false;
        }

        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        const showUtilities = inBottomPanel(panels.utilities, x, y);

        if (!utilitiesShortcutActive) {
            visibilities.utilities = showUtilities;
        } else if (showUtilities) {
            utilitiesShortcutActive = false;
        }

        if (inBarArea(x, y)) {
            bar.checkPopout(barCoord(x, y));
        } else if ((!popouts.currentName.startsWith("traymenu") || (popouts.current?.depth ?? 0) <= 1) && !inLeftPanel(panels.popouts, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    Connections {
        target: root.visibilities

        function onLauncherChanged() {
            if (!root.visibilities.launcher) {
                root.dashboardShortcutActive = false;
                root.utilitiesShortcutActive = false;

                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea)
                    root.visibilities.dashboard = false;
            }
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea)
                    root.dashboardShortcutActive = true;
            } else {
                root.dashboardShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea)
                    root.utilitiesShortcutActive = true;
            } else {
                root.utilitiesShortcutActive = false;
            }
        }
    }
}
