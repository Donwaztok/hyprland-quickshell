import QtQuick

QtObject {
    id: root
    property string path: ""
    property bool recursive: false
    property bool watchChanges: false
    property bool showHidden: false
    property bool sortReverse: false
    property int filter: 0  // NoFilter=0, Images=1, Files=2, Dirs=3
    property var nameFilters: []
    property var entries: []
    readonly property int count: entries.length

    function get(index) {
        return entries[index] ?? null
    }
}
