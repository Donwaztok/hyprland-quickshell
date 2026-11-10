pragma Singleton

import Quickshell

// The shell's own bar icons, which can sit in the status area, the tray, or be hidden (Config.bar.icons).
// Tray apps join the same lists as "app:<status notifier id>". Views: modules/bar/components/statusIcons/.
Singleton {
    readonly property var shell: ({
            audio: {
                label: qsTr("Speakers"),
                glyph: "volume_up",
                popout: "audio"
            },
            microphone: {
                label: qsTr("Microphone"),
                glyph: "mic",
                popout: "audio"
            },
            kblayout: {
                label: qsTr("Keyboard layout"),
                glyph: "keyboard",
                popout: "kblayout"
            },
            network: {
                label: qsTr("Network"),
                glyph: "wifi",
                popout: "network"
            },
            bluetooth: {
                label: qsTr("Bluetooth"),
                glyph: "bluetooth",
                popout: "bluetooth"
            },
            drives: {
                label: qsTr("Drives"),
                glyph: "usb",
                popout: "drives"
            },
            battery: {
                label: qsTr("Battery"),
                glyph: "battery_full",
                popout: "battery"
            },
            lockstatus: {
                label: qsTr("Caps lock"),
                glyph: "keyboard_capslock",
                popout: "lockstatus"
            }
        })

    function isApp(id: string): bool {
        return id.startsWith("app:");
    }

    function appId(id: string): string {
        return id.slice(4);
    }
}
