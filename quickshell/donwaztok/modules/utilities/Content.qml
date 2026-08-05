import "cards"
import qs.components
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var visibilities
    required property Item popouts

    property alias audioProfilesOpen: audioDevices.profilesOpen
    readonly property real audioProfilesWidth: 280

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        AudioProfiles {
            Layout.preferredWidth: root.audioProfilesOpen ? root.audioProfilesWidth : 0
            Layout.maximumWidth: root.audioProfilesOpen ? root.audioProfilesWidth : 0
            Layout.fillHeight: true
            Layout.minimumHeight: cardsColumn.implicitHeight
            opacity: root.audioProfilesOpen ? 1 : 0
            visible: Layout.preferredWidth > 0
            clip: true
            showDisabled: audioDevices.showDisabled

            onCloseRequested: root.audioProfilesOpen = false

            Behavior on Layout.preferredWidth {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }

        ColumnLayout {
            id: cardsColumn

            Layout.fillWidth: true
            Layout.preferredWidth: Config.utilities.sizes.width - Appearance.padding.large * 2
            spacing: Appearance.spacing.normal

            IdleInhibit {}

            AudioDevices {
                id: audioDevices
            }

            Toggles {
                visibilities: root.visibilities
                popouts: root.popouts
            }
        }
    }
}
