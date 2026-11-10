import qs.components
import qs.config
import QtQuick

MaterialIcon {
    property color colour
    property bool inTray

    color: colour

    pointSizeScale: Config.barThicknessScale
    text: "usb"
}
