import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick

// Info icon that explains the control next to it. The tooltip opens on hover, on keyboard focus and on
// click or tap (touch has no hover).
Item {
    id: root

    required property string text
    property bool pinned: false
    // Focus taken by a click; any other focus came from the keyboard and shows the tooltip by itself.
    property bool clickFocused: false
    // Read by Tooltip, which shows itself while this is true.
    readonly property bool hovered: hover.hovered || pinned || (activeFocus && !clickFocused)

    implicitWidth: icon.implicitWidth + Appearance.padding.small * 2
    implicitHeight: implicitWidth

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("More information")
    Accessible.description: root.text

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.pinned = !root.pinned;
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.pinned = false;
        }
    }
    onActiveFocusChanged: {
        if (!activeFocus) {
            pinned = false;
            clickFocused = false;
        }
    }

    StateLayer {
        radius: Appearance.rounding.full

        function onClicked(): void {
            // Focus lets a click elsewhere close it again (see onActiveFocusChanged).
            root.clickFocused = true;
            root.forceActiveFocus();
            root.pinned = !root.pinned;
        }
    }

    HoverHandler {
        id: hover
    }

    // Focus ring for keyboard users.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colours.palette.m3secondary
        visible: root.activeFocus && !root.clickFocused
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: "info"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.normal
    }

    Tooltip {
        target: root
        text: root.text
        delay: 200
    }
}
