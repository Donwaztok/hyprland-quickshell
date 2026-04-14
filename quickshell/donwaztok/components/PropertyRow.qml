import qs.components
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property string label
    required property string value
    property bool showTopMargin: false

    spacing: Appearance.spacing.small / 2

    StyledText {
        Layout.topMargin: root.showTopMargin ? Appearance.spacing.normal : 0
        text: root.label
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        color: Colours.light ? Colours.palette.m3onSurfaceVariant : Qt.lighter(Colours.palette.m3onSurfaceVariant, 1.2)
    }

    StyledText {
        text: root.value
        color: Colours.palette.m3onSurface
        font.pointSize: Appearance.font.size.normal
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
