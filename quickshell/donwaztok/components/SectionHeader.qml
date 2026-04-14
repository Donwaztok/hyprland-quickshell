import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property string title
    property string description: ""

    spacing: Appearance.spacing.smaller

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pointSize: Appearance.font.size.larger
        font.weight: Font.DemiBold
        color: Colours.palette.m3onSurface
    }

    StyledText {
        visible: root.description !== ""
        text: root.description
        color: Colours.light ? Colours.palette.m3onSurfaceVariant : Qt.lighter(Colours.palette.m3onSurfaceVariant, 1.22)
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.topMargin: visible ? Appearance.spacing.smaller : 0
    }
}
