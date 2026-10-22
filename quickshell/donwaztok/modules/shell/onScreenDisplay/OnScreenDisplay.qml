import qs
import qs.services
import qs.services.shell as Shell
import qs.components
import qs.components.effects
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property string protectionMessage: ""
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    property string currentIndicator: "volume"
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "indicators/VolumeIndicator.qml"
        },
        {
            id: "brightness",
            sourceUrl: "indicators/BrightnessIndicator.qml"
        },
    ]

    function triggerOsd(timeout) {
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.interval = timeout > 0 ? timeout : (Config.shellOptions?.osd?.timeout ?? 1000);
        osdTimeout.restart();
    }

    Timer {
        id: osdTimeout
        interval: Config.shellOptions?.osd?.timeout ?? 1000
        repeat: false
        running: false
        onTriggered: {
            GlobalStates.osdVolumeOpen = false;
            root.protectionMessage = "";
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.protectionMessage = "";
            root.currentIndicator = "brightness";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready)
                return;
            if (GlobalStates.audioOutputSwitcherOpen)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onMutedChanged() {
            if (!Audio.ready)
                return;
            if (GlobalStates.audioOutputSwitcherOpen)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onSinkChanged() {
            if (!Audio.ready)
                return;
            if (GlobalStates.audioOutputSwitcherOpen)
                return;
            root.protectionMessage = "";
            root.currentIndicator = "volume";
            root.triggerOsd(2000);
        }
    }

    Loader {
        id: osdLoader
        active: GlobalStates.osdVolumeOpen

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"

            readonly property string caPos: Config.loaded ? Config.bar.position : "top"
            readonly property int caInset: Config.loaded ? Config.bar.sizes.thickness + Config.border.thickness : 40
            readonly property int gap: 5

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: caPos !== "bottom"
                bottom: caPos === "bottom"
            }
            mask: Region {
                item: osdValuesWrapper
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: caPos === "top" ? caInset : gap
                bottom: caPos === "bottom" ? caInset : gap
                left: caPos === "left" ? caInset : gap
                right: caPos === "right" ? caInset : gap
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight
            visible: osdLoader.active

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: GlobalStates.osdVolumeOpen = false
                    }

                    Column {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 0

                        Loader {
                            id: osdIndicatorLoader
                            source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl
                        }

                        Item {
                            id: protectionMessageWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitHeight: protectionMessageBackground.implicitHeight
                            implicitWidth: protectionMessageBackground.implicitWidth
                            opacity: root.protectionMessage !== "" ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    duration: Appearance.anim.durations.small
                                }
                            }

                            Elevation {
                                anchors.fill: protectionMessageBackground
                                radius: protectionMessageBackground.radius
                                level: 2
                            }
                            StyledRect {
                                id: protectionMessageBackground
                                anchors.centerIn: parent
                                color: Shell.Colours.palette.m3error
                                implicitHeight: protectionMessageRowLayout.implicitHeight + Appearance.padding.normal * 2
                                implicitWidth: protectionMessageRowLayout.implicitWidth + Appearance.padding.large * 2
                                radius: Appearance.rounding.normal

                                RowLayout {
                                    id: protectionMessageRowLayout
                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.small
                                    MaterialIcon {
                                        text: "dangerous"
                                        fill: 1
                                        color: Shell.Colours.palette.m3onError
                                    }
                                    StyledText {
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Shell.Colours.palette.m3onError
                                        wrapMode: Text.Wrap
                                        text: root.protectionMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "osdVolume"

        function trigger() {
            root.triggerOsd();
        }

        function hide() {
            GlobalStates.osdVolumeOpen = false;
        }

        function toggle() {
            GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen;
        }
    }
    GlobalShortcut {
        appid: "donwaztok"
        name: "osdVolumeTrigger"
        description: "Triggers volume OSD on press"

        onPressed: {
            root.triggerOsd();
        }
    }
    GlobalShortcut {
        appid: "donwaztok"
        name: "osdVolumeHide"
        description: "Hides volume OSD on press"

        onPressed: {
            GlobalStates.osdVolumeOpen = false;
        }
    }
}
