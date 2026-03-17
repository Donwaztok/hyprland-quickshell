import QtQuick

QtObject {
    id: root
    property int capacity: 0
    property int count: 0
    property var _data: []
    readonly property var values: _data.slice()
    readonly property real maximum: _data.length ? Math.max(..._data) : 0

    function setCapacity(cap) {
        if (capacity === cap) return
        capacity = cap
        while (_data.length > capacity)
            _data.shift()
        count = _data.length
    }

    function push(value) {
        _data = _data.slice()
        _data.push(value)
        while (_data.length > capacity && capacity > 0)
            _data.shift()
        count = _data.length
    }

    function clear() {
        _data = []
        count = 0
    }

    function at(index) {
        return _data[index] ?? 0
    }
}
