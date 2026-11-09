pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Removable media (replaces the udiskie tray): mount, open, eject.
ColumnLayout {
    id: root

    required property Item wrapper
    property string pendingKey: ""

    spacing: Appearance.spacing.small

    StyledText {
        Layout.topMargin: Appearance.padding.normal
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Drives")
        font.weight: 500
    }

    Repeater {
        model: ScriptModel {
            values: FileManagerService.removableMounts
        }

        RowLayout {
            id: drive

            required property var modelData
            readonly property string key: modelData.devicePath || modelData.mount
            readonly property bool busy: FileManagerService.jobActive && root.pendingKey === key

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: drive.modelData.tran === "mmc" ? "sd_card" : "usb"
            }

            ColumnLayout {
                Layout.leftMargin: Appearance.spacing.small / 2
                Layout.rightMargin: Appearance.spacing.small / 2
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: drive.modelData.name
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: drive.modelData.mounted ? qsTr("%1 free of %2").arg(FileManagerService.formatBytes(drive.modelData.free)).arg(FileManagerService.formatBytes(drive.modelData.total)) : qsTr("Not mounted")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                }
            }

            Loader {
                active: drive.modelData.mounted
                sourceComponent: Item {
                    implicitWidth: actionBtn.implicitWidth
                    implicitHeight: actionBtn.implicitHeight

                    StateLayer {
                        radius: Appearance.rounding.full

                        function onClicked(): void {
                            FileManagerService.requestOpenPath(drive.modelData.mount);
                            root.wrapper.hasCurrent = false;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "folder_open"
                    }
                }
            }

            StyledRect {
                id: actionBtn

                implicitWidth: implicitHeight
                implicitHeight: actionIcon.implicitHeight + Appearance.padding.small

                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, drive.modelData.mounted ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: drive.busy
                }

                StateLayer {
                    color: drive.modelData.mounted ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    disabled: FileManagerService.jobActive

                    function onClicked(): void {
                        root.pendingKey = drive.key;
                        if (drive.modelData.mounted)
                            FileManagerService.ejectVolume(drive.modelData.mount, null);
                        else
                            FileManagerService.mountVolume(drive.modelData.devicePath, null);
                    }
                }

                MaterialIcon {
                    id: actionIcon

                    anchors.centerIn: parent
                    animate: true
                    text: drive.modelData.mounted ? "eject" : "input"
                    color: drive.modelData.mounted ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    opacity: drive.busy ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.normal
        inactiveColour: Colours.palette.m3primary
        inactiveOnColour: Colours.palette.m3onPrimary
        verticalPadding: Appearance.padding.small
        text: qsTr("Mount disc image")
        icon: "album"

        onClicked: {
            FileManagerService.requestMountDiscImage();
            root.wrapper.hasCurrent = false;
        }
    }
}
