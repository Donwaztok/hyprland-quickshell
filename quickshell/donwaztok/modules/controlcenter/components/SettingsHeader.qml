pragma ComponentBehavior: Bound

import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// Pane intro: left-aligned title + muted subtitle (GNOME Settings content area; no duplicate window title).
Item {
    id: root

    property string icon: ""
    required property string title
    property string subtitle: ""

    /** Space below this header; use 0 when a custom rule/spacer follows (e.g. split-pane detail). */
    property int layoutBottomMargin: Appearance.spacing.larger

    Layout.fillWidth: true
    Layout.bottomMargin: root.layoutBottomMargin
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.left: parent.left
        width: parent.width
        spacing: Appearance.spacing.normal

        RowLayout {
            visible: root.icon !== ""
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: root.icon
                fill: 0
                font.pointSize: Appearance.font.size.extraLarge
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.title
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: Font.DemiBold
                color: Colours.palette.m3onSurface
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            visible: root.icon === ""
            Layout.fillWidth: true
            text: root.title
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurface
            wrapMode: Text.WordWrap
        }

        StyledText {
            visible: root.subtitle !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.subtitle
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
