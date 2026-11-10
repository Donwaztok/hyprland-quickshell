pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts
import "statusIcons"

// The bar's status area: shell icons placed in Config.bar.icons.status, in that order.
Item {
    id: root

    readonly property bool barVertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property int effectiveInnerWidth: Config.bar.sizes.thickness
    readonly property int spaceSm: Math.max(1, Math.round(Appearance.spacing.small * Config.barThicknessScale))
    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconColumn
    // Lock keys collapse to nothing while off, but the grid still spaces them.
    readonly property bool lockStatusEmpty: Config.bar.icons.status.includes("lockstatus") && !Hypr.capsLock && !Hypr.numLock

    clip: !barVertical
    implicitWidth: barVertical ? root.effectiveInnerWidth : iconColumn.implicitWidth
    implicitHeight: barVertical ? (iconColumn.implicitHeight - (root.lockStatusEmpty ? iconColumn.spacing : 0)) : root.effectiveInnerWidth

    GridLayout {
        id: iconColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: barVertical ? parent.top : undefined
        anchors.bottom: barVertical ? parent.bottom : undefined
        anchors.verticalCenter: barVertical ? undefined : parent.verticalCenter
        anchors.margins: 0

        flow: root.barVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.barVertical ? -1 : 1
        columns: root.barVertical ? 1 : -1
        rowSpacing: root.spaceSm
        columnSpacing: root.spaceSm

        Repeater {
            model: Config.bar.icons.status.filter(id => id in BarIcons.shell)

            StatusIconView {
                required property string modelData
                // Bar.qml walks up from the hovered child to the nearest `name` to pick the popout.
                readonly property string name: BarIcons.shell[modelData].popout

                Layout.alignment: root.barVertical ? Qt.AlignHCenter : Qt.AlignVCenter
                iconId: modelData
                colour: root.colour
            }
        }
    }
}
