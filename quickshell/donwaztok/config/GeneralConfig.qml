import Quickshell.Io

JsonObject {
    property list<string> excludedScreens: []
    property Apps apps: Apps {}
    property Idle idle: Idle {}
    property Battery battery: Battery {}

    component Apps: JsonObject {
        property list<string> terminal: ["kitty"]
        property list<string> audio: ["pavucontrol"]
        property list<string> playback: ["mpv"]
        property list<string> explorer: ["thunar"]
    }

    component Idle: JsonObject {
        property bool lockBeforeSleep: true
        property bool inhibitWhenAudio: false
        property list<var> timeouts: [
            {
                timeout: 180,
                idleAction: "lock"
            },
            {
                timeout: 300,
                idleAction: "dpms off",
                returnAction: "dpms on"
            },
            {
                timeout: 600,
                idleAction: ["systemctl", "suspend-then-hibernate"]
            }
        ]
    }

    component Battery: JsonObject {
        property list<var> warnLevels: [
            {
                level: 20,
                title: qsTr("Low battery"),
                message: qsTr("Plug in a charger"),
                icon: "battery_android_frame_2"
            },
            {
                level: 10,
                title: qsTr("Critical"),
                message: qsTr("Plug in now"),
                icon: "battery_android_frame_1"
            },
            {
                level: 5,
                title: qsTr("Critical battery"),
                message: qsTr("Plug in now!"),
                icon: "battery_android_alert",
                critical: true
            },
        ]
        property int criticalLevel: 3
    }
}
