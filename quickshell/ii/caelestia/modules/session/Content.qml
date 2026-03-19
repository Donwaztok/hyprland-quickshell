pragma ComponentBehavior: Bound

import caelestia.components
import caelestia.services
import caelestia.config
import caelestia.utils
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities

    readonly property int pad: Appearance.padding.large

    implicitWidth: buttonRow.implicitWidth + pad * 2
    implicitHeight: bg.height + hoverLabel.implicitHeight + Appearance.spacing.normal

    Rectangle {
        id: bg

        width: parent.width
        height: buttonRow.implicitHeight + root.pad * 2
        radius: Config.border.rounding
        color: Colours.palette.m3surface

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }
    }

    Row {
        id: buttonRow

        x: root.pad
        y: root.pad
        spacing: Appearance.spacing.large

        SessionButton {
            id: hibernate

            icon: Config.session.icons.hibernate
            command: Config.session.commands.hibernate
            label: qsTr("Hibernate")

            KeyNavigation.right: logout
        }

        SessionButton {
            id: logout

            icon: Config.session.icons.logout
            command: Config.session.commands.logout
            label: qsTr("Log out")

            KeyNavigation.left: hibernate
            KeyNavigation.right: reboot
        }

        SessionButton {
            id: reboot

            icon: Config.session.icons.reboot
            command: Config.session.commands.reboot
            label: qsTr("Reboot")

            KeyNavigation.left: logout
            KeyNavigation.right: shutdown
        }

        SessionButton {
            id: shutdown

            icon: Config.session.icons.shutdown
            command: Config.session.commands.shutdown
            label: qsTr("Shutdown")

            KeyNavigation.left: reboot

            Component.onCompleted: shutdown.forceActiveFocus()

            Connections {
                target: root.visibilities

                function onSessionChanged(): void {
                    if (root.visibilities.session)
                        shutdown.forceActiveFocus();
                }

                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher)
                        shutdown.forceActiveFocus();
                }
            }
        }
    }

    StyledText {
        id: hoverLabel

        anchors.top: bg.bottom
        anchors.topMargin: Appearance.spacing.normal
        anchors.horizontalCenter: parent.horizontalCenter
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.small
        opacity: text ? 1 : 0
        text: {
            const items = [hibernate, logout, reboot, shutdown];
            for (const item of items)
                if (item.hovered)
                    return item.label;
            for (const item of items)
                if (item.activeFocus)
                    return item.label;
            return "";
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.small
            }
        }
    }

    component SessionButton: StyledRect {
        id: button

        required property string icon
        required property list<string> command
        required property string label
        readonly property bool hovered: hoverHandler.hovered

        implicitWidth: Config.session.sizes.button
        implicitHeight: Config.session.sizes.button

        radius: Appearance.rounding.large
        color: button.activeFocus ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer

        HoverHandler {
            id: hoverHandler
        }

        Keys.onEnterPressed: Quickshell.execDetached(button.command)
        Keys.onReturnPressed: Quickshell.execDetached(button.command)
        Keys.onEscapePressed: root.visibilities.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J && KeyNavigation.right) {
                    KeyNavigation.right.focus = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_K && KeyNavigation.left) {
                    KeyNavigation.left.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.right) {
                KeyNavigation.right.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.left) {
                    KeyNavigation.left.focus = true;
                    event.accepted = true;
                }
            }
        }

        StateLayer {
            id: stateLayer

            radius: parent.radius
            color: button.activeFocus ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            function onClicked(): void {
                Quickshell.execDetached(button.command);
            }
        }

        MaterialIcon {
            anchors.centerIn: parent

            text: button.icon
            color: button.activeFocus ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: 500
        }
    }
}
