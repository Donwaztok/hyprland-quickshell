pragma Singleton
import QtQuick

QtObject {
    function get(url, callback) {
        if (typeof callback === "function")
            Qt.callLater(callback, "{}");
    }
}
