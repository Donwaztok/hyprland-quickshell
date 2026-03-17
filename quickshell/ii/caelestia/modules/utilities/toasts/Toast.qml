import QtQuick

QtObject {
    property bool closed: false
    property string title: ""
    property string message: ""
    property string icon: ""
    property int timeout: 5000
    property int type: 0  // Info=0, Success=1, Warning=2, Error=3
    function close() { closed = true }
    function lock(sender) {}
    function unlock(sender) {}
}
