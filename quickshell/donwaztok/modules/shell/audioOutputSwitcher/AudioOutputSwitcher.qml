import qs
import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property bool closeArmed: false

    function openSwitcher(): void {
        GlobalStates.osdVolumeOpen = false;
        GlobalStates.audioOutputSwitcherOpen = true;
        root.closeArmed = false;
        Audio.cycleOutputSwitcher();
        armCloseTimer.restart();
    }

    function closeSwitcher(): void {
        if (!GlobalStates.audioOutputSwitcherOpen && !Audio.outputSwitcherActive)
            return;

        root.closeArmed = false;
        armCloseTimer.stop();
        superWatchdog.stop();
        GlobalStates.audioOutputSwitcherOpen = false;
        Audio.closeOutputSwitcher();
    }

    function deviceIcon(sink: var, selected: bool): string {
        const label = ((sink?.description || sink?.nickname || sink?.name || "") + "").toLowerCase();
        if (label.includes("hdmi") || label.includes("displayport") || label.includes("dp "))
            return selected ? "tv" : "tv";
        if (label.includes("headphone") || label.includes("headset") || label.includes("stinger") || label.includes("cloud"))
            return "headphones";
        if (label.includes("bluetooth") || label.includes("bluez"))
            return "bluetooth_audio";
        if (label.includes("usb"))
            return "usb";
        return selected ? "speaker" : "speaker_group";
    }

    Timer {
        id: armCloseTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (GlobalStates.audioOutputSwitcherOpen)
                root.closeArmed = true;
        }
    }

    Timer {
        id: superWatchdog
        interval: 60
        repeat: true
        running: GlobalStates.audioOutputSwitcherOpen && root.closeArmed
        onTriggered: {
            if (!superHeldProbe.running)
                superHeldProbe.running = true;
        }
    }

    Process {
        id: superHeldProbe
        command: [
            "hyprctl",
            "eval",
            'if not hl.is_key_down("Super_L") and not hl.is_key_down("Super_R") then hl.dispatch(hl.dsp.global("donwaztok:audioOutputClose")) end'
        ]
    }

    Connections {
        target: GlobalStates

        function onAudioOutputSwitcherOpenChanged(): void {
            if (!GlobalStates.audioOutputSwitcherOpen && Audio.outputSwitcherActive)
                Audio.closeOutputSwitcher();
            if (!GlobalStates.audioOutputSwitcherOpen) {
                root.closeArmed = false;
                armCloseTimer.stop();
            }
        }

        function onSuperDownChanged(): void {
            if (root.closeArmed && !GlobalStates.superDown)
                root.closeSwitcher();
        }
    }

    Loader {
        id: switcherLoader
        active: GlobalStates.audioOutputSwitcherOpen

        sourceComponent: PanelWindow {
            id: switcherRoot
            color: "transparent"
            screen: root.focusedScreen

            readonly property string barPos: Config.bar.position
            readonly property int barInset: Config.bar.sizes.thickness + Config.border.thickness
            readonly property int edgeGap: Appearance.spacing.large * 2

            Connections {
                target: root
                function onFocusedScreenChanged(): void {
                    switcherRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:audioOutputSwitcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {}

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: true
                bottom: true
                right: true
            }

            margins {
                top: barPos === "top" ? barInset : edgeGap
                bottom: barPos === "bottom" ? barInset : edgeGap
                right: (barPos === "right" ? barInset : 0) + edgeGap
            }

            implicitWidth: panelWrap.implicitWidth
            visible: switcherLoader.active

            Item {
                id: panelWrap
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: panel.implicitWidth
                implicitHeight: panel.implicitHeight

                property bool shown: false
                property real slideX: shown ? 0 : 16
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.97

                transform: Translate {
                    x: panelWrap.slideX
                }

                Component.onCompleted: shown = true

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }
                Behavior on scale {
                    Anim {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
                    }
                }
                Behavior on slideX {
                    Anim {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
                    }
                }

                Elevation {
                    anchors.fill: panel
                    radius: panel.radius
                    opacity: panelWrap.opacity
                    z: -1
                    level: 2
                }

                StyledRect {
                    id: panel
                    anchors.centerIn: parent
                    implicitWidth: 280
                    implicitHeight: listColumn.implicitHeight + Appearance.padding.large * 2
                    radius: Appearance.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer

                    ColumnLayout {
                        id: listColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Appearance.padding.large
                        }
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledRect {
                                implicitWidth: headerIcon.implicitHeight + Appearance.padding.small * 2
                                implicitHeight: implicitWidth
                                radius: Appearance.rounding.full
                                color: Colours.palette.m3primaryContainer

                                MaterialIcon {
                                    id: headerIcon
                                    anchors.centerIn: parent
                                    text: "graphic_eq"
                                    color: Colours.palette.m3onPrimaryContainer
                                    fill: 1
                                    font.pointSize: Appearance.font.size.large
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Audio output")
                                color: Colours.palette.m3onSurface
                                font.pointSize: Appearance.font.size.normal
                                font.weight: 500
                                elide: Text.ElideRight
                            }
                        }

                        Repeater {
                            model: Audio.sinks

                            StyledRect {
                                id: row
                                required property var modelData
                                required property int index

                                readonly property string sinkName: modelData?.name || ""
                                readonly property bool selected: {
                                    const selectedName = Audio.outputSwitcherSelectedName || Audio.sink?.name || "";
                                    return sinkName !== "" && sinkName === selectedName;
                                }

                                Layout.fillWidth: true
                                implicitHeight: rowInner.implicitHeight + Appearance.padding.normal * 2
                                radius: Appearance.rounding.normal
                                color: selected ? Qt.alpha(Colours.palette.m3primary, 0.14) : "transparent"

                                Behavior on color {
                                    CAnim {}
                                }

                                RowLayout {
                                    id: rowInner
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: Appearance.padding.normal
                                        rightMargin: Appearance.padding.normal
                                    }
                                    spacing: Appearance.spacing.normal

                                    MaterialIcon {
                                        text: root.deviceIcon(row.modelData, row.selected)
                                        color: row.selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        fill: row.selected ? 1 : 0
                                        font.pointSize: Appearance.font.size.large

                                        Behavior on fill {
                                            Anim {
                                                duration: Appearance.anim.durations.small
                                            }
                                        }
                                        Behavior on color {
                                            CAnim {}
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData?.description || modelData?.nickname || modelData?.name || qsTr("Unknown")
                                        color: row.selected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.smaller
                                        font.weight: row.selected ? 500 : 400
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "audioOutputCycle"
        description: "Cycle audio output while Super is held"

        onPressed: root.openSwitcher()
    }

    GlobalShortcut {
        appid: "donwaztok"
        name: "audioOutputClose"
        description: "Close audio output switcher on Super release"

        onPressed: root.closeSwitcher()
    }
}
