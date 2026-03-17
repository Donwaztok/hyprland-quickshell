import QtQuick

Item {
    id: root
    property HyprDevices devices: dev
    property QtObject options: opts
    function refreshDevices() {}
    function batchMessage(arr) {}
    HyprDevices {
        id: dev
    }
    QtObject {
        id: opts
    }
}
