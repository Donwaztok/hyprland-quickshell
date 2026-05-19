import qs.components
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property string entry
    required property var visibilities
    required property bool selected

    readonly property string emoji: entry.split(" ")[0] ?? ""
    readonly property string label: {
        const parts = entry.split(" ");
        return parts.length > 1 ? parts.slice(1).join(" ") : entry;
    }

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            if (root.emoji.length === 0)
                return;
            Quickshell.execDetached(["wl-copy", root.emoji]);
            root.visibilities.launcher = false;
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: root.emoji
        font.pointSize: 26
        horizontalAlignment: Text.AlignHCenter
    }

    ToolTip {
        visible: hover.containsMouse && root.label.length > 0
        text: root.label
        delay: 400
    }

    HoverHandler {
        id: hover
    }
}
