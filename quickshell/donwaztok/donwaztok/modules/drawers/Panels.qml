import donwaztok.config
import donwaztok.services
import donwaztok.modules.notifications as Notifications
import donwaztok.modules.session as Session
import donwaztok.modules.launcher as Launcher
import donwaztok.modules.dashboard as Dashboard
import donwaztok.modules.bar.popouts as BarPopouts
import donwaztok.modules.utilities as Utilities
import donwaztok.modules.utilities.toasts as Toasts
import donwaztok.modules.sidebar as Sidebar
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property Item bar

    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popouts
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar

    anchors.fill: parent
    anchors.leftMargin: Math.max(Config.border.thickness, bar.leftMargin)
    anchors.rightMargin: Math.max(Config.border.thickness, bar.rightMargin)
    anchors.topMargin: Math.max(Config.border.thickness, bar.topMargin)
    anchors.bottomMargin: Math.max(Config.border.thickness, bar.bottomMargin)

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        panels: root

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Session.Wrapper {
        id: session

        visibilities: root.visibilities
        panels: root

        anchors.centerIn: parent
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.Wrapper {
        id: popouts

        screen: root.screen

        x: {
            if (isDetached)
                return (root.width - nonAnimWidth) / 2;
            if (Config.bar.position === "left")
                return 0;
            if (Config.bar.position === "right")
                return root.width - nonAnimWidth;
            const off = currentCenter - parent.bar.leftMargin - nonAnimWidth / 2;
            const diff = root.width - Math.floor(off + nonAnimWidth);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }
        y: {
            if (isDetached)
                return (root.height - nonAnimHeight) / 2;
            if (Config.bar.position === "top")
                return 0;
            if (Config.bar.position === "bottom")
                return root.height - nonAnimHeight;
            const off = currentCenter - Config.border.thickness - nonAnimHeight / 2;
            const diff = root.height - Math.floor(off + nonAnimHeight);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }
    }

    Utilities.Wrapper {
        id: utilities

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popouts

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Appearance.padding.normal
    }

    Sidebar.Wrapper {
        id: sidebar

        visibilities: root.visibilities
        panels: root

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
    }

    Component.onCompleted: {
        const mon = Hypr.monitorFor(screen);
        if (mon)
            Visibilities.registerPopouts(mon, popouts);
    }
}
