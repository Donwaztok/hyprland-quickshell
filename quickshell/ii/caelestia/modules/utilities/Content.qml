import "cards"
import caelestia.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var visibilities
    required property Item popouts

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        IdleInhibit {}

        Toggles {
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }
}
