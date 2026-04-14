import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property string label
    property alias checked: toggle.checked
    property alias toggle: toggle

    Layout.fillWidth: true
    spacing: Appearance.spacing.smaller

    StyledText {
        Layout.fillWidth: true
        text: root.label
        font.weight: Font.Medium
        color: Colours.palette.m3onSurface
    }

    StyledSwitch {
        id: toggle

        cLayer: 2
    }
}
