import QtQuick

Item {
    id: root
    property var keyboards: [mainKeyboard]
    HyprKeyboard {
        id: mainKeyboard
        main: true
    }
}
