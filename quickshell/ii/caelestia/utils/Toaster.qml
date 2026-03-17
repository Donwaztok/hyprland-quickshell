pragma Singleton
import QtQuick

QtObject {
    property list<var> toasts: []
    function toast(title, message, icon, type) {}
}
