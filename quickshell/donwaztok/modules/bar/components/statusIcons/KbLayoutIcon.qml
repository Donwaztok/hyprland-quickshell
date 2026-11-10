import qs.components
import qs.services.shell
import qs.config
import QtQuick

StyledText {
    property color colour
    property bool inTray

    color: colour

    animate: true
    text: Hypr.kbLayout
    font.family: Appearance.font.family.mono
    font.pointSize: Math.max(6, Appearance.font.size.small * Config.barThicknessScale)
}
