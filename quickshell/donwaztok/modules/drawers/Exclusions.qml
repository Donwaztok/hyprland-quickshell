pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Reserves the bar and the frame borders on this screen through Hyprland's monitor rule (reserved_area).
// One layer surface per edge would do the same, but each costs a render thread and ~8 MB of memory.
// The rule outlives the shell, so a reload or restart re-applies the same values without moving windows.
Scope {
    id: root

    required property ShellScreen screen
    required property Item bar

    readonly property int left: root.bar.leftMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    readonly property int top: root.bar.topMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    readonly property int right: root.bar.rightMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    readonly property int bottom: root.bar.bottomMargin > 0 ? root.bar.exclusiveZone : Config.border.thickness
    // A rule with only output and reserved_area merges into the monitor's rule: mode, position and scale stay.
    readonly property string rule: `hl.monitor({ output = "${root.screen.name}", reserved_area = { top = ${root.top}, bottom = ${root.bottom}, left = ${root.left}, right = ${root.right} } })`

    function apply(): void {
        applyProc.exec(["hyprctl", "eval", root.rule]);
    }

    // Coalesces bursts (bar width animating, several edges changing at once) into one eval.
    onRuleChanged: applyTimer.restart()
    Component.onCompleted: apply()

    Timer {
        id: applyTimer

        interval: 50
        onTriggered: root.apply()
    }

    Connections {
        target: Hyprland

        // A config reload resets monitor rules to the Lua files, and a reconnected monitor starts without one.
        function onRawEvent(event: HyprlandEvent): void {
            if (["configreloaded", "monitoradded", "monitoraddedv2"].includes(event.name))
                applyTimer.restart();
        }
    }

    Process {
        id: applyProc
    }
}
