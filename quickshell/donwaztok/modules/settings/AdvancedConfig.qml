import QtQuick
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "colors"
        title: qsTr("Theme")

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Shell palette: edit services/m3/Colours.qml (builtinSchemes.defaultDark / defaultLight and M3Palette defaults), then restart Quickshell. Hyprland, Fuzzel, and GTK stay in ~/.config separately.")
        }
    }
}
