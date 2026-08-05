import "cards"
import qs.components
import qs.config
import qs.services.shell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var visibilities
    required property Item popouts
    required property var screen

    property alias audioProfilesOpen: audioDevices.profilesOpen
    readonly property real audioProfilesWidth: 280

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Component.onCompleted: {
        if (!Audio.cards || Audio.cards.length === 0)
            Audio.refreshCards();
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        Item {
            id: profilesClip

            Layout.preferredWidth: root.audioProfilesOpen ? root.audioProfilesWidth : 0
            Layout.maximumWidth: root.audioProfilesOpen ? root.audioProfilesWidth : 0
            Layout.fillHeight: true
            Layout.minimumHeight: cardsColumn.implicitHeight
            clip: true
            opacity: root.audioProfilesOpen ? 1 : 0

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

            Loader {
                active: root.audioProfilesOpen || profilesClip.width > 1
                width: root.audioProfilesWidth
                height: parent.height

                sourceComponent: AudioProfiles {
                    width: root.audioProfilesWidth
                    height: profilesClip.height
                    showDisabled: audioDevices.showDisabled

                    onCloseRequested: root.audioProfilesOpen = false
                }
            }
        }

        ColumnLayout {
            id: cardsColumn

            Layout.fillWidth: true
            Layout.preferredWidth: Config.utilities.sizes.width - Appearance.padding.large * 2
            spacing: Appearance.spacing.normal

            IdleInhibit {}

            Sliders {
                screen: root.screen
            }

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
