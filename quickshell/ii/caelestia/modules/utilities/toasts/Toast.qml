import QtQuick

QtObject {
    enum Type {
        Info = 0,
        Success = 1,
        Warning = 2,
        Error = 3
    }

    property bool closed: false
    property string title: ""
    property string message: ""
    property string icon: ""
    property int timeout: 5000
    property int type: Toast.Info
    function close() { closed = true }
    function lock(sender) {}
    function unlock(sender) {}
}
