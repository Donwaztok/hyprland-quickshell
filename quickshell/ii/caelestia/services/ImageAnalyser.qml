import QtQuick

QtObject {
    id: root
    property var sourceItem
    property url source
    property color dominantColour: "transparent"
    property real luminance: 0.5
    function requestUpdate() {}
}
