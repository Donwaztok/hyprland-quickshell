import QtQuick

QtObject {
    id: root

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

    signal finishedClose

    property var _locks: []

    function close() {
        if (root.closed)
            return;
        root.closed = true;
        if (root._locks.length === 0)
            root.finishedClose();
    }

    function lock(sender) {
        if (!sender)
            return;
        if (root._locks.indexOf(sender) < 0)
            root._locks = root._locks.concat([sender]);
    }

    function unlock(sender) {
        root._locks = root._locks.filter(s => s !== sender);
        if (root.closed && root._locks.length === 0)
            root.finishedClose();
    }

    Component.onCompleted: {
        if (root.timeout > 0)
            closeTimer.start();
    }

    // QtObject has no default property; Timer must be a named property.
    property Timer closeTimer: Timer {
        interval: root.timeout
        repeat: false
        onTriggered: root.close()
    }
}
