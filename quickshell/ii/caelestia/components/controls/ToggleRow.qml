import caelestia.components
import caelestia.components.controls
import caelestia.services
import caelestia.config
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property string label
    property alias checked: toggle.checked
    property alias toggle: toggle

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    StyledText {
        Layout.fillWidth: true
        text: root.label
    }

    StyledSwitch {
        id: toggle

        cLayer: 2
    }
}
