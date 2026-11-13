pragma ComponentBehavior: Bound

// Super+Y dictation, typed as you speak: scripts/dictation/dictate.py records the mic, runs whisper-server,
// and types each phrase into the focused window when you pause. The modal shows the waveform and the live
// text, never takes the keyboard, and closes after a few seconds of silence or on Super+Y.
// Nothing stays loaded once it closes.
import qs.components
import qs.components.effects
import qs.components.misc
import qs.config
import qs.services.shell
import qs.utils
import qs.modules.utilities.toasts
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property int barCount: 36

    // "" closed, then listening -> finishing -> done; closing plays the exit animation.
    property string phase: ""
    property var levels: new Array(barCount + 1).fill(0)
    property real level: 0
    property string transcript: ""
    property string partial: ""
    property bool failed: false
    property int download: -1 // percent while the model is fetched on first use
    // The waveform turns into a travelling wave while there is nothing to listen to yet, or any more.
    readonly property bool waiting: phase === "finishing" || download >= 0
    property bool closeWhenDone: false
    property var screen: null
    readonly property string liveText: (transcript + " " + partial).trim()

    function start(): void {
        if (phase === "listening" || phase === "finishing")
            return;
        doneTimer.stop();
        closeTimer.stop();
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null;
        levels = new Array(barCount + 1).fill(0);
        level = 0;
        transcript = "";
        partial = "";
        failed = false;
        download = -1;
        closeWhenDone = false;
        phase = "listening";
        // Esc and Super+Y live in this submap while the modal is up (hypr/lua/hyprland/keybinds.lua).
        Hyprland.dispatch('hl.dsp.submap("dictation")');
        dictate.running = true;
    }

    function finish(): void {
        if (phase !== "listening")
            return;
        phase = "finishing";
        dictate.signal(15); // the phrase in progress is still typed
    }

    // Esc: type what is still pending, then close without the "done" pause.
    function dismiss(): void {
        closeWhenDone = true;
        if (phase === "listening")
            finish();
        else if (phase === "done")
            close();
    }

    function close(): void {
        if (phase === "" || phase === "closing")
            return;
        if (dictate.running)
            dictate.signal(2); // cancel: drop the phrase in progress
        phase = "closing";
        closeTimer.restart();
    }

    function pushLevel(db: real): void {
        // -55 dB (room noise) .. -10 dB (loud speech) -> 0..1, falling gently so bars don't flicker
        const raw = isFinite(db) ? Math.max(0, Math.min(1, (db + 55) / 45)) : 0;
        const v = Math.max(raw, level * 0.6);
        level = v;
        const next = levels.slice(1);
        next.push(v);
        levels = next;
    }

    Timer {
        id: closeTimer
        interval: Appearance.anim.durations.normal
        onTriggered: {
            root.phase = "";
            Hyprland.dispatch('hl.dsp.submap("reset")');
        }
    }

    Timer {
        id: doneTimer
        interval: 1600
        onTriggered: root.close()
    }

    Process {
        id: dictate
        command: ["python3", "-I", Quickshell.shellPath("scripts/dictation/dictate.py")]
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ");
                const kind = sp < 0 ? line : line.slice(0, sp);
                const value = sp < 0 ? "" : line.slice(sp + 1);
                if (kind === "level") {
                    root.download = -1;
                    root.pushLevel(parseFloat(value));
                } else if (kind === "download") {
                    root.download = parseInt(value);
                } else if (kind === "partial") {
                    root.partial = value;
                } else if (kind === "commit") {
                    root.transcript = (root.transcript + " " + value).trim();
                    root.partial = "";
                } else if (kind === "error") {
                    root.failed = true;
                    Toaster.toast(qsTr("Dictation failed"), value, "mic_off", Toast.Error);
                }
            }
        }
        stderr: StdioCollector {
            id: dictateErr
        }
        onExited: code => {
            if (root.phase === "closing" || root.phase === "")
                return;
            if (code !== 0 && !root.failed)
                Toaster.toast(qsTr("Dictation failed"), dictateErr.text.trim().split("\n").pop(), "mic_off",
                              Toast.Error);
            if (code !== 0 || root.failed || root.closeWhenDone)
                return root.close();
            root.partial = "";
            root.phase = "done";
            doneTimer.restart();
        }
    }

    Loader {
        id: loader
        active: root.phase !== ""

        sourceComponent: PanelWindow {
            id: win

            readonly property string barPos: Config.loaded ? Config.bar.position : "top"
            readonly property int inset: Config.loaded ? Config.bar.sizes.thickness + Config.border.thickness :
                                                         40
            readonly property bool shown: root.phase !== "closing" && entered
            property bool entered: false

            screen: root.screen
            color: "transparent"
            WlrLayershell.namespace: "quickshell:dictation"
            WlrLayershell.layer: WlrLayer.Overlay
            // Never take the keyboard: the typed text has to land in the app underneath.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.bottom: true
            margins.bottom: (barPos === "bottom" ? inset : 0) + Appearance.spacing.large * 2
            implicitWidth: 560
            implicitHeight: 260
            mask: Region {
                item: card
            }

            Component.onCompleted: entered = true

            StyledRect {
                id: card

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    level: 3
                    z: -1
                }

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.large
                implicitWidth: content.implicitWidth + Appearance.padding.large * 2
                implicitHeight: content.implicitHeight + Appearance.padding.large * 2
                radius: liveBox.visible ? Appearance.rounding.large : Appearance.rounding.full
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.85
                transform: Translate {
                    y: win.shown ? 0 : 48
                    Behavior on y {
                        Anim {
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }
                }

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }
                Behavior on scale {
                    Anim {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }
                Behavior on implicitWidth {
                    Anim {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }
                Behavior on implicitHeight {
                    Anim {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }
                Behavior on radius {
                    Anim {}
                }

                ColumnLayout {
                    id: content

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    // What you said so far, one line that never rewraps (so the card height never moves);
                    // the start is elided, so the newest words stay.
                    StyledText {
                        id: liveBox

                        visible: root.liveText !== ""
                        Layout.preferredWidth: topRow.implicitWidth
                        elide: Text.ElideLeft
                        font.pointSize: Appearance.font.size.normal
                        text: root.liveText
                    }

                    RowLayout {
                        id: topRow

                        spacing: Appearance.spacing.normal

                        // Mic badge: a halo that breathes with the voice while listening.
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 40
                            implicitHeight: 40

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: width
                                radius: width / 2
                                color: Colours.palette.m3primary
                                opacity: root.phase === "listening" ? 0.25 : 0
                                scale: 1 + root.level * 0.6
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                                Behavior on opacity {
                                    Anim {}
                                }
                            }

                            StyledRect {
                                anchors.centerIn: parent
                                width: parent.width
                                height: width
                                radius: width / 2
                                color: root.phase === "done" ? Colours.palette.m3secondaryContainer :
                                                               Colours.palette.m3primary

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    animate: true
                                    text: {
                                        if (root.phase === "done")
                                            return root.transcript ? "check" : "mic_off";
                                        if (root.download >= 0)
                                            return "download";
                                        return root.phase === "finishing" ? "graphic_eq" : "mic";
                                    }
                                    color: root.phase === "done" ? Colours.palette.m3onSecondaryContainer :
                                                                   Colours.palette.m3onPrimary
                                    font.pointSize: Appearance.font.size.large
                                    fill: 1
                                }
                            }
                        }

                        // Waveform, newest level on the right. Bars never change height once drawn: on each
                        // level the strip shifts one slot and slides back, so it scrolls like a tape instead
                        // of every bar bouncing. One extra bar waits behind the right edge. While finishing it
                        // becomes a travelling wave.
                        Item {
                            id: wave

                            readonly property int step: 7
                            property real t: 0

                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: root.barCount * step - 3
                            implicitHeight: 40
                            clip: true

                            NumberAnimation on t {
                                running: root.waiting
                                from: 0
                                to: Math.PI * 2
                                duration: 900
                                loops: Animation.Infinite
                            }

                            Connections {
                                target: root

                                function onLevelsChanged(): void {
                                    slide.restart();
                                }
                            }

                            NumberAnimation {
                                id: slide

                                target: strip
                                property: "x"
                                from: 0
                                to: -wave.step
                                duration: 96 // one level update
                            }

                            Row {
                                id: strip

                                height: parent.height
                                spacing: wave.step - 4

                                Repeater {
                                    model: root.barCount + 1

                                    Rectangle {
                                        required property int index

                                        readonly property real wavy: 0.25 + 0.2 * Math.sin(wave.t - index * 0.35)
                                        readonly property real v: root.waiting ? wavy
                                                                                             : root.levels[index]

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 4
                                        height: 4 + v * 36
                                        radius: 2
                                        color: Colours.palette.m3primary
                                        opacity: 0.35 + 0.65 * index / root.barCount
                                    }
                                }
                            }
                        }

                        StyledText {
                            id: status

                            Layout.alignment: Qt.AlignVCenter
                            // While downloading the percent changes every second: no fade, and the width of
                            // "100%" kept from the start, so the card does not resize on each digit.
                            Layout.minimumWidth: root.download >= 0 ? widest.width : 0
                            animate: root.download < 0
                            animateProp: "opacity"

                            TextMetrics {
                                id: widest

                                font: status.font
                                text: qsTr("Downloading model %1%").arg(100)
                            }
                            elide: Text.ElideRight
                            font.pointSize: Appearance.font.size.normal
                            color: Colours.palette.m3onSurfaceVariant
                            text: {
                                if (root.phase === "finishing")
                                    return qsTr("Finishing…");
                                if (root.phase === "done")
                                    return root.transcript ? qsTr("Typed")
                                                           : qsTr("Didn't catch anything");
                                if (root.download >= 0)
                                    return qsTr("Downloading model %1%").arg(root.download);
                                return qsTr("Listening");
                            }
                        }
                    }
                }
            }
        }
    }

    CustomShortcut {
        name: "dictationToggle"
        description: "Start dictation, or finish it"
        onPressed: root.phase === "listening" ? root.finish() : root.start()
    }

    CustomShortcut {
        name: "dictationDismiss"
        description: "Close the dictation modal (Esc), typing what is still pending"
        onPressed: root.dismiss()
    }

    IpcHandler {
        target: "dictation"

        function toggle(): void {
            root.phase === "listening" ? root.finish() : root.start();
        }

        function cancel(): void {
            root.close();
        }
    }
}
