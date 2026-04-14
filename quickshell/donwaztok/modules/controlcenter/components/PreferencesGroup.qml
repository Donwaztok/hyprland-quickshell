pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// GNOME / libadwaita-style preferences section: bold title, muted caption, grouped rows in a card.
ColumnLayout {
    id: root

    required property string title
    property string description: ""
    default property alias data: cardColumn.data

    spacing: Appearance.spacing.smaller
    Layout.fillWidth: true

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pointSize: Appearance.font.size.larger
        font.weight: Font.DemiBold
        color: Colours.palette.m3onSurface
    }

    StyledText {
        visible: root.description !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.description
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        color: Colours.palette.m3onSurfaceVariant
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.smaller
        implicitHeight: cardColumn.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.normal
        color: ControlCenterChrome.settingsGroupCard
        border.width: 1
        border.color: ControlCenterChrome.settingsGroupCardBorder

        Elevation {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            level: Colours.light ? 1 : 2
        }

        ColumnLayout {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal
        }
    }
}
