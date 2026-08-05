import qs.services
import qs.services.shell
import qs.components
import qs.components.effects
import qs.config as Theme
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: cheatsheetLoader
        active: false

        sourceComponent: PanelWindow {
            id: cheatsheetRoot
            visible: cheatsheetLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                cheatsheetLoader.active = false;
            }

            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:cheatsheet"
            color: "transparent"

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(cheatsheetRoot);
                panelOpacity = 1;
                panelScale = 1;
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(cheatsheetRoot);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    cheatsheetRoot.hide();
                }
            }

            property real panelOpacity: 0
            property real panelScale: 0.96

            Behavior on panelOpacity {
                Anim {
                    duration: Theme.Appearance.anim.durations.small
                }
            }
            Behavior on panelScale {
                Anim {
                    duration: Theme.Appearance.anim.durations.small
                    easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45)
                opacity: cheatsheetRoot.panelOpacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: cheatsheetRoot.hide()
                }
            }

            StyledRect {
                id: cheatsheetBackground
                anchors.centerIn: parent
                opacity: cheatsheetRoot.panelOpacity
                scale: cheatsheetRoot.panelScale
                radius: Theme.Appearance.rounding.large
                color: Colours.shellSurface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
                focus: true

                readonly property real padding: Theme.Appearance.padding.large
                readonly property real maxWidth: Math.min(cheatsheetRoot.width * 0.9, 1280)
                readonly property real maxHeight: cheatsheetRoot.height * 0.86

                implicitWidth: Math.min(contentColumn.implicitWidth + padding * 2, maxWidth)
                implicitHeight: Math.min(contentColumn.implicitHeight + padding * 2, maxHeight)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        cheatsheetRoot.hide();
                }

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    z: -1
                    level: 3
                    opacity: parent.opacity
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: cheatsheetBackground.padding
                    spacing: Theme.Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.Appearance.spacing.smaller

                        StyledRect {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: Theme.Appearance.rounding.normal
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "keyboard"
                                fill: 1
                                font.pointSize: Theme.Appearance.font.size.large
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: qsTr("Shortcuts")
                                font.pointSize: Theme.Appearance.font.size.large
                                font.weight: Font.DemiBold
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                text: qsTr("Super + / to toggle")
                                font.pointSize: Theme.Appearance.font.size.small
                                font.weight: Font.Medium
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        Item {
                            implicitWidth: 40
                            implicitHeight: 40

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                font.pointSize: Theme.Appearance.font.size.large
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: width / 2
                                color: Colours.palette.m3onSurface

                                function onClicked(): void {
                                    cheatsheetRoot.hide();
                                }
                            }
                        }
                    }

                    CheatsheetKeybinds {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        maxWidth: cheatsheetBackground.maxWidth - cheatsheetBackground.padding * 2
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }

        function close(): void {
            cheatsheetLoader.active = false;
        }

        function open(): void {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "cheatsheetToggle"
        description: "Toggles cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "cheatsheetOpen"
        description: "Opens cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "cheatsheetClose"
        description: "Closes cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = false;
        }
    }
}
