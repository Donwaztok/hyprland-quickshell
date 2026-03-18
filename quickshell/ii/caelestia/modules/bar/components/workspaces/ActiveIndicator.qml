import caelestia.components
import caelestia.components.effects
import caelestia.services
import caelestia.utils
import caelestia.config
import Quickshell
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property ShellScreen screen
    required property bool barVertical
    required property Repeater workspaces
    required property Item mask

    readonly property int activeWsId: Config.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen)?.activeWorkspace?.id ?? 1) : Hypr.activeWsId
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown
    readonly property int currentWsIdx: Math.max(0, Math.min(Config.bar.workspaces.shown - 1, activeWsId - 1 - groupOffset))

    readonly property string activeDisplayText: {
        const ws = Hypr.workspaces.values.find(w => w.id === root.activeWsId);
        const wsName = !ws || ws.name === root.activeWsId ? root.activeWsId : ws.name[0];
        let displayName = wsName.toString();
        if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") displayName = displayName.toUpperCase();
        else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") displayName = displayName.toLowerCase();
        const label = Config.bar.workspaces.label || displayName;
        return Config.bar.workspaces.activeLabel || label;
    }

    property real leading: workspaces.count > 0 ? (root.barVertical ? (workspaces.itemAt(currentWsIdx)?.y ?? 0) : (workspaces.itemAt(currentWsIdx)?.x ?? 0)) : 0
    property real trailing: workspaces.count > 0 ? (root.barVertical ? (workspaces.itemAt(currentWsIdx)?.y ?? 0) : (workspaces.itemAt(currentWsIdx)?.x ?? 0)) : 0
    property real currentSize: workspaces.count > 0 ? (workspaces.itemAt(currentWsIdx)?.size ?? 0) : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            if (root.barVertical)
                return ws ? Math.min(ws.y + ws.size - offset, s) : 0;
            return ws ? Math.min(ws.x + ws.size - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    y: root.barVertical ? (offset + root.mask.y) : 0
    implicitWidth: root.barVertical ? (Config.bar.sizes.innerWidth - Appearance.padding.small * 2) : size
    implicitHeight: root.barVertical ? size : (Config.bar.sizes.innerWidth - Appearance.padding.small * 2)
    radius: Appearance.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        visible: root.barVertical
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: root.barVertical ? -parent.x : -parent.offset
        y: root.barVertical ? -parent.offset : -parent.y
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: root.barVertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.barVertical ? undefined : parent.verticalCenter
    }

    RowLayout {
        visible: !root.barVertical
        anchors.fill: parent
        anchors.margins: Math.floor(Appearance.spacing.small / 2)
        spacing: Math.floor(Appearance.spacing.small / 2)
        layoutDirection: Qt.LeftToRight

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2
            Layout.preferredHeight: Config.bar.sizes.innerWidth - Appearance.padding.small * 2
            text: root.activeDisplayText
            color: Colours.palette.m3onPrimary
            verticalAlignment: Qt.AlignVCenter
            horizontalAlignment: Qt.AlignHCenter
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.bar.workspaces.showWindows
            spacing: Math.floor(Appearance.spacing.small / 2)
            layoutDirection: Qt.LeftToRight
            Repeater {
                model: ScriptModel {
                    values: {
                        const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === root.activeWsId);
                        const maxIcons = Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }
                MaterialIcon {
                    required property var modelData
                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onPrimary
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
    }

    Behavior on leading {
        enabled: Config.bar.workspaces.activeTrail
        EAnim {}
    }

    Behavior on trailing {
        enabled: Config.bar.workspaces.activeTrail
        EAnim {
            duration: Appearance.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: Config.bar.workspaces.activeTrail
        EAnim {}
    }

    Behavior on offset {
        enabled: !Config.bar.workspaces.activeTrail
        EAnim {}
    }

    Behavior on size {
        enabled: !Config.bar.workspaces.activeTrail
        EAnim {}
    }

    component EAnim: Anim {
        easing.bezierCurve: Appearance.anim.curves.emphasized
    }
}
