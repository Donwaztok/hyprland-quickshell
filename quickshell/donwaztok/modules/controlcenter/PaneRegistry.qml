pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<QtObject> panes: [
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string title: qsTr("Network")
            readonly property string icon: "router"
            readonly property string component: "network/NetworkingPane.qml"
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string title: qsTr("Bluetooth")
            readonly property string icon: "settings_bluetooth"
            readonly property string component: "bluetooth/BtPane.qml"
        },
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string title: qsTr("Sound")
            readonly property string icon: "volume_up"
            readonly property string component: "audio/AudioPane.qml"
        },
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string title: qsTr("Appearance")
            readonly property string icon: "palette"
            readonly property string component: "appearance/AppearancePane.qml"
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string title: qsTr("Taskbar")
            readonly property string icon: "task_alt"
            readonly property string component: "taskbar/TaskbarPane.qml"
        },
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string title: qsTr("Launcher")
            readonly property string icon: "apps"
            readonly property string component: "launcher/LauncherPane.qml"
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string title: qsTr("Dashboard")
            readonly property string icon: "dashboard"
            readonly property string component: "dashboard/DashboardPane.qml"
        },
        QtObject {
            readonly property string id: "hyprlandLayout"
            readonly property string label: "hyprlandLayout"
            readonly property string title: qsTr("Hyprland layout")
            readonly property string icon: "view_quilt"
            readonly property string component: "hyprland/HyprlandLayoutPane.qml"
        },
        QtObject {
            readonly property string id: "hyprlandLook"
            readonly property string label: "hyprlandLook"
            readonly property string title: qsTr("Hyprland look")
            readonly property string icon: "palette"
            readonly property string component: "hyprland/HyprlandLookPane.qml"
        },
        QtObject {
            readonly property string id: "hyprlandInput"
            readonly property string label: "hyprlandInput"
            readonly property string title: qsTr("Hyprland input")
            readonly property string icon: "mouse"
            readonly property string component: "hyprland/HyprlandInputPane.qml"
        },
        QtObject {
            readonly property string id: "hyprlandAdvanced"
            readonly property string label: "hyprlandAdvanced"
            readonly property string title: qsTr("Hyprland compositor")
            readonly property string icon: "tune"
            readonly property string component: "hyprland/HyprlandAdvancedPane.qml"
        }
    ]

    readonly property int count: panes.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            result.push(panes[i].label);
        }
        return result;
    }

    function getByIndex(index: int): QtObject {
        if (index >= 0 && index < panes.length) {
            return panes[index];
        }
        return null;
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].label === label) {
                return i;
            }
        }
        return -1;
    }

    function getByLabel(label: string): QtObject {
        const index = getIndexByLabel(label);
        return getByIndex(index);
    }

    function getById(id: string): QtObject {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id) {
                return panes[i];
            }
        }
        return null;
    }
}
