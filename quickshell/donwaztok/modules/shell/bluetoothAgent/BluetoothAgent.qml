pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.effects
import qs.services.shell
import qs.config
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Bluetooth pairing agent (replaces blueman-applet's): bin/donwaztok-bt-agent relays
// BlueZ's requests here and this dialog answers them. Same look as the polkit dialog.
Scope {
    id: root

    property var request: null // {type, id?, device, code?, uuid?}
    readonly property bool needsInput: request?.type === "pin" || request?.type === "passkey"

    function answer(ok: bool, value: string): void {
        if (root.request?.id)
            agent.write(JSON.stringify({
                id: root.request.id,
                ok: ok,
                value: value
            }) + "\n");
        root.request = null;
    }

    Process {
        id: agent

        running: !!Bluetooth.defaultAdapter
        stdinEnabled: true
        command: [Quickshell.shellPath("bin/donwaztok-bt-agent")]
        stderr: SplitParser {
            onRead: line => console.warn("[bluetooth agent]", line)
        }
        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.type === "ready")
                    return;
                if (msg.type === "cancel" || msg.type === "done") {
                    root.request = null;
                } else {
                    root.answer(false, ""); // reject the request this replaces, or BlueZ waits for its timeout
                    root.request = msg;
                }
            }
        }
    }

    LazyLoader {
        active: root.request !== null

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            color: "transparent"
            WlrLayershell.namespace: "quickshell:bluetoothAgent"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            Item {
                id: content

                property bool shown: false

                anchors.fill: parent
                focus: true
                Component.onCompleted: shown = true
                Keys.onEscapePressed: root.answer(false, "")

                Rectangle {
                    anchors.fill: parent
                    color: Colours.palette.m3scrim
                    opacity: content.shown ? 0.5 : 0

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
                    implicitHeight: column.implicitHeight + Appearance.padding.large * 2

                    radius: Appearance.rounding.normal
                    color: Colours.shellSurface
                    opacity: content.shown ? 1 : 0
                    scale: content.shown ? 1 : 0.7

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
                        id: column

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Appearance.padding.large

                        spacing: Appearance.spacing.normal

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "bluetooth"
                            color: Colours.palette.m3primary
                            fill: 1
                            font.pointSize: Appearance.font.size.extraLarge * 1.5
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.request?.type === "service" ? qsTr("Bluetooth access") : qsTr("Pairing request")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const device = root.request?.device ?? "";
                                switch (root.request?.type) {
                                case "confirm":
                                    return qsTr("Does %1 show this code?").arg(device);
                                case "display":
                                    return qsTr("Type this code on %1, then press Enter.").arg(device);
                                case "pin":
                                    return qsTr("Enter the PIN for %1.").arg(device);
                                case "passkey":
                                    return qsTr("Enter the code shown on %1.").arg(device);
                                case "service":
                                    return qsTr("Allow %1 to connect to this computer?").arg(device);
                                default:
                                    return qsTr("Allow %1 to pair with this computer?").arg(device);
                                }
                            }
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !!root.request?.code
                            text: root.request?.code ?? ""
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.extraLarge
                            font.letterSpacing: 4
                        }

                        StyledTextField {
                            id: inputField

                            Layout.fillWidth: true
                            Layout.topMargin: Appearance.spacing.small
                            visible: root.needsInput
                            focus: root.needsInput
                            placeholderText: root.request?.type === "passkey" ? qsTr("Code") : qsTr("PIN")
                            inputMethodHints: root.request?.type === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone

                            onAccepted: root.answer(true, text)
                            Keys.onEscapePressed: root.answer(false, "")

                            Connections {
                                target: root

                                function onRequestChanged(): void {
                                    inputField.text = "";
                                }
                            }
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
                                text: root.request?.type === "display" ? qsTr("Close") : qsTr("Cancel")

                                onClicked: root.answer(false, "")
                            }

                            TextButton {
                                Layout.fillWidth: true
                                Layout.minimumHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                                visible: root.request?.type !== "display"
                                inactiveColour: Colours.palette.m3primary
                                inactiveOnColour: Colours.palette.m3onPrimary
                                text: root.request?.type === "confirm" ? qsTr("Pair") : qsTr("OK")
                                enabled: !root.needsInput || inputField.text.length > 0
                                opacity: enabled ? 1 : 0.5

                                onClicked: root.answer(true, inputField.text)
                            }
                        }
                    }
                }
            }
        }
    }
}
