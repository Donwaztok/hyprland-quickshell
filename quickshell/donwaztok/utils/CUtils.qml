pragma Singleton
import QtQuick

QtObject {
    function toLocalFile(url) {
        const s = Qt.resolvedUrl(url).toString()
        return s.replace(/^file:\/\//, "")
    }
    function copyFile(src, dest) { return false }
    function deleteFile(url) { return false }
    function saveItem(item, cache, cb) { if (typeof cb === "function") cb() }
}
