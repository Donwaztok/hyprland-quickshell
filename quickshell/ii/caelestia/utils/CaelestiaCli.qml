pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool available: false

    function exec(args: var): void {
        if (available && args && args.length > 0) {
            const cmd = ["caelestia"].concat(args);
            Quickshell.execDetached(cmd);
        }
    }

    Component.onCompleted: {
        checkProcess.running = true;
    }

    Process {
        id: checkProcess

        running: false
        command: ["which", "caelestia"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim().length > 0
        }
    }
}
