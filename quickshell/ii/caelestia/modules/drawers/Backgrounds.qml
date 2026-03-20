import caelestia.services
import caelestia.config
import caelestia.modules.osd as Osd
import caelestia.modules.notifications as Notifications
import caelestia.modules.launcher as Launcher
import caelestia.modules.dashboard as Dashboard
import caelestia.modules.bar.popouts as BarPopouts
import caelestia.modules.utilities as Utilities
import caelestia.modules.sidebar as Sidebar
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

    Osd.Background {
        wrapper: root.panels.osd

        startX: root.width - root.panels.sidebar.width
        startY: (root.height - wrapper.height) / 2 - rounding
    }

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
