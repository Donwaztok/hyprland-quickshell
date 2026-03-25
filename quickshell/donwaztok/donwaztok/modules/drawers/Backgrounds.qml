import donwaztok.services
import donwaztok.config
import donwaztok.modules.notifications as Notifications
import donwaztok.modules.launcher as Launcher
import donwaztok.modules.dashboard as Dashboard
import donwaztok.modules.bar.popouts as BarPopouts
import donwaztok.modules.utilities as Utilities
import donwaztok.modules.sidebar as Sidebar
import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    required property Panels panels
    required property Item bar

    anchors.fill: parent
    anchors.margins: Config.border.thickness
    anchors.leftMargin: Math.max(Config.border.thickness, bar.leftMargin)
    anchors.rightMargin: Math.max(Config.border.thickness, bar.rightMargin)
    anchors.topMargin: Math.max(Config.border.thickness, bar.topMargin)
    anchors.bottomMargin: Math.max(Config.border.thickness, bar.bottomMargin)
    preferredRendererType: Shape.CurveRenderer

    Notifications.Background {
        wrapper: root.panels.notifications
        sidebar: sidebar

        startX: root.width
        startY: 0
    }

    Launcher.Background {
        wrapper: root.panels.launcher

        startX: (root.width - wrapper.width) / 2 - rounding
        startY: root.height
    }

    Dashboard.Background {
        wrapper: root.panels.dashboard

        startX: (root.width - wrapper.width) / 2 - rounding
        startY: 0
    }

    BarPopouts.Background {
        wrapper: root.panels.popouts
        invertBottomRounding: Config.bar.position === "top" || Config.bar.position === "bottom"
            ? (wrapper.x + wrapper.width + 1 >= root.width)
            : (wrapper.y + wrapper.height + 1 >= root.height)
    }

    Utilities.Background {
        wrapper: root.panels.utilities
        sidebar: sidebar

        startX: root.width
        startY: root.height
    }

    Sidebar.Background {
        id: sidebar

        wrapper: root.panels.sidebar
        panels: root.panels

        startX: root.width
        startY: root.panels.notifications.height
    }
}
