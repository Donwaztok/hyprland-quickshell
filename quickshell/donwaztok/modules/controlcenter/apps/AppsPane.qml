pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property string editor: {
        const v = Config.general.apps.editor;
        return v && String(v).length ? String(v) : TextEditorService.appId;
    }

    anchors.fill: parent

    StyledFlickable {
        id: contentFlickable
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: contentLayout.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: contentFlickable
        }

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.normal

            Item {
                Layout.fillWidth: true
                implicitHeight: constrainedColumn.implicitHeight

                readonly property real maxContentWidth: 860

                ColumnLayout {
                    id: constrainedColumn
                    width: Math.min(parent.width, parent.maxContentWidth)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.normal

                    SettingsHeader {
                        title: qsTr("Applications")
                        subtitle: qsTr("Default apps used by Donwaztok and registered with the desktop.")
                        layoutBottomMargin: Appearance.spacing.smaller
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Appearance.spacing.smaller
                        implicitHeight: 1
                        color: ControlCenterChrome.paneSectionRule
                    }

                    PreferencesGroup {
                        Layout.fillWidth: true
                        title: qsTr("Default applications")
                        description: qsTr("System default leaves the desktop MIME handler unchanged.")

                        OptionSelectRow {
                            Layout.fillWidth: true
                            label: qsTr("Text editor")
                            currentValue: root.editor
                            options: TextEditorService.editorOptionList
                            onOptionChosen: v => {
                                root.editor = v;
                                TextEditorService.setDefaultEditor(v);
                            }
                        }

                        OptionSelectRow {
                            Layout.fillWidth: true
                            label: qsTr("File manager")
                            currentValue: DefaultApps.explorerId
                            options: DefaultApps.explorerOptionList
                            onOptionChosen: v => DefaultApps.setApp("explorer", v)
                        }

                        OptionSelectRow {
                            Layout.fillWidth: true
                            label: qsTr("Terminal")
                            currentValue: DefaultApps.terminalId
                            options: DefaultApps.terminalOptionList
                            onOptionChosen: v => DefaultApps.setApp("terminal", v)
                        }

                        OptionSelectRow {
                            Layout.fillWidth: true
                            label: qsTr("Media player")
                            currentValue: DefaultApps.playbackId
                            options: DefaultApps.playbackOptionList
                            onOptionChosen: v => DefaultApps.setApp("playback", v)
                        }

                        OptionSelectRow {
                            Layout.fillWidth: true
                            label: qsTr("Volume mixer")
                            currentValue: DefaultApps.audioId
                            options: DefaultApps.audioOptionList
                            onOptionChosen: v => DefaultApps.setApp("audio", v)
                        }
                    }
                }
            }
        }
    }
}
