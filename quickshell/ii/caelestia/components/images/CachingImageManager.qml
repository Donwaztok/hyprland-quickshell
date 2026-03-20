import QtQuick

QtObject {
    id: root

    property string path: ""
    property var item
    property url cacheDir

    onPathChanged: updateSource()

    function updateSource(): void {
        if (!item)
            return;
        const p = String(path || "").trim();
        if (!p.length) {
            item.source = "";
            return;
        }
        if (p.startsWith("file:") || p.startsWith("qrc:") || p.startsWith("http:") || p.startsWith("https:")) {
            item.source = Qt.resolvedUrl(p);
            return;
        }
        const norm = p.replace(/\\/g, "/");
        item.source = Qt.resolvedUrl("file://" + (norm.startsWith("/") ? norm : `/${norm}`));
    }

    Component.onCompleted: Qt.callLater(() => root.updateSource())
}
