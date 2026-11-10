import QtQuick

// Draws one shell icon by id (see utils/BarIcons.qml), in the status area or in the tray's square slot.
Loader {
    id: root

    required property string iconId
    property color colour
    property bool inTray

    sourceComponent: {
        switch (root.iconId) {
        case "audio":
            return audio;
        case "microphone":
            return microphone;
        case "kblayout":
            return kblayout;
        case "network":
            return network;
        case "bluetooth":
            return bluetooth;
        case "drives":
            return drives;
        case "battery":
            return battery;
        case "lockstatus":
            return lockstatus;
        }
        return null;
    }

    Component {
        id: audio
        AudioIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: microphone
        MicrophoneIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: kblayout
        KbLayoutIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: network
        NetworkIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: bluetooth
        BluetoothIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: drives
        DrivesIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: battery
        BatteryIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
    Component {
        id: lockstatus
        LockStatusIcon {
            colour: root.colour
            inTray: root.inTray
        }
    }
}
