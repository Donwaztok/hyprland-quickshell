import QtQuick

QtObject {
    id: root
    property string path: ""
    property var favouriteApps: []
    property var entries: []
    readonly property var apps: entries
    function incrementFrequency(id) {}
}
