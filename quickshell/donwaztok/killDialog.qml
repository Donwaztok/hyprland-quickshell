//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config

// Standalone window (`qs -p killDialog.qml`) opened by services/ConflictKiller.qml.
ApplicationWindow {
    id: root

    property int conflictCount: 0
    onConflictCountChanged: {
        if (conflictCount === 0)
            root.close();
    }

    // This process must not overwrite the main shell's config, except for an explicit "Always".
    function rememberAlways(key: string): void {
        DonwaztokConfigStore.blockWrites = false;
        Config.shellOptions.conflictKiller[key] = true;
        DonwaztokConfigStore.writeFullConfig();
        DonwaztokConfigStore.blockWrites = true;
    }

    visible: true
    onClosing: Qt.quit()
    title: qsTr("Shell conflicts killer")

    Component.onCompleted: {
        DonwaztokConfigStore.readWriteDelay = 0;
        DonwaztokConfigStore.blockWrites = true;
    }

    minimumWidth: 420
    minimumHeight: 300
    maximumWidth: 420
    maximumHeight: 300
    width: 420
    height: 300
    color: Colours.palette.m3surface

    component ConflictingProgramGroup: ColumnLayout {
        id: conflictGroup

        required property list<string> programs
        required property string description
        signal alwaysSelected

        visible: false
        spacing: Appearance.spacing.small
        onVisibleChanged: root.conflictCount += visible ? 1 : -1

        Process {
            running: true
            command: ["pidof", ...conflictGroup.programs]
            onExited: exitCode => {
                if (exitCode === 0)
                    conflictGroup.visible = true;
            }
        }

        StyledText {
            text: conflictGroup.programs.join(", ")
            font.pointSize: Appearance.font.size.normal
            font.weight: 500
        }

        StyledText {
            Layout.fillWidth: true
            text: conflictGroup.description
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Appearance.spacing.small
            spacing: Appearance.spacing.small

            TextButton {
                type: TextButton.Text
                text: qsTr("No")
                onClicked: conflictGroup.visible = false
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("Always")
                onClicked: {
                    Quickshell.execDetached(["killall", ...conflictGroup.programs]);
                    conflictGroup.alwaysSelected();
                    conflictGroup.visible = false;
                }
            }

            TextButton {
                text: qsTr("Kill")
                onClicked: {
                    Quickshell.execDetached(["killall", ...conflictGroup.programs]);
                    conflictGroup.visible = false;
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "warning"
                fill: 1
                color: Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Kill conflicting programs?")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: root.close()
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colours.palette.m3surfaceContainerLow
            radius: Appearance.rounding.normal

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.large

                ConflictingProgramGroup {
                    Layout.fillWidth: true
                    programs: ["kded6"]
                    description: qsTr("Conflicts with the shell's system tray implementation")
                    onAlwaysSelected: root.rememberAlways("autoKillTrays")
                }

                ConflictingProgramGroup {
                    Layout.fillWidth: true
                    programs: ["mako", "dunst"]
                    description: qsTr("Conflicts with the shell's notification implementation")
                    onAlwaysSelected: root.rememberAlways("autoKillNotificationDaemons")
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
