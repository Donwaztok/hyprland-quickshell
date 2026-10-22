pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool usePasswordChars: !PolkitService.flow?.responseVisible ?? true
    property bool shown: false

    function submit(): void {
        PolkitService.submit(inputField.text);
    }

    Component.onCompleted: shown = true
    Keys.onEscapePressed: PolkitService.cancel()

    Connections {
        target: PolkitService

        function onInteractionAvailableChanged(): void {
            if (!PolkitService.interactionAvailable)
                return;
            inputField.text = "";
            inputField.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: root.shown ? 0.5 : 0

        Behavior on opacity {
            Anim {}
        }
    }

    Elevation {
        anchors.fill: dialog
        radius: dialog.radius
        level: 3
        opacity: dialog.opacity
        scale: dialog.scale
    }

    StyledRect {
        id: dialog

        anchors.centerIn: parent
        implicitWidth: 420
        implicitHeight: content.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.normal
        color: Colours.shellSurface
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.7

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: PolkitService.failed ? "gpp_bad" : "security"
                color: PolkitService.failed ? Colours.palette.m3error : Colours.palette.m3primary
                fill: 1
                font.pointSize: Appearance.font.size.extraLarge * 1.5
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Authentication required")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            StyledText {
                Layout.fillWidth: true
                text: PolkitService.cleanMessage
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            StyledTextField {
                id: inputField

                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                focus: true
                enabled: PolkitService.interactionAvailable
                placeholderText: PolkitService.cleanPrompt
                echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal

                onAccepted: root.submit()
                Keys.onEscapePressed: PolkitService.cancel()
            }

            StyledText {
                Layout.fillWidth: true
                visible: PolkitService.failed
                text: qsTr("Authentication failed. Try again.")
                color: Colours.palette.m3error
                font.pointSize: Appearance.font.size.small
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.topMargin: Appearance.spacing.small
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                TextButton {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                    inactiveColour: Colours.palette.m3secondaryContainer
                    inactiveOnColour: Colours.palette.m3onSecondaryContainer
                    text: qsTr("Cancel")

                    onClicked: PolkitService.cancel()
                }

                TextButton {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary
                    text: qsTr("OK")
                    enabled: PolkitService.interactionAvailable
                    opacity: enabled ? 1 : 0.5

                    onClicked: root.submit()
                }
            }
        }
    }
}
