import QtQuick

QtObject {
    id: root
    property int bars: 45
    property list<real> values: []

    function _regen() {
        const v = []
        for (let i = 0; i < Math.max(0, bars); i++) v.push(0)
        values = v
    }

    Component.onCompleted: _regen()
    onBarsChanged: _regen()
}
