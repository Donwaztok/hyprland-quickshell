import qs.components
import qs.services
import qs.services.shell
import qs.config
import Quickshell.Services.UPower
import QtQuick

// The inner fill is the real charge; color is the state. Without a battery, shows the power profile.
Item {
    id: batt

    property color colour
    property bool inTray
    readonly property int iconBox: Math.max(18, Math.round(Appearance.font.size.larger * Config.barThicknessScale))
    readonly property bool laptop: UPower.displayDevice.isLaptopBattery
    readonly property var charge: {
        if (batt.laptop) {
            const fraction = Math.max(0, Math.min(1, UPower.displayDevice.percentage));
            const charging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state);
            return {
                fraction,
                charging
            };
        }

        const list = DeviceBatteries.devices;
        let best = null;
        for (let i = 0; i < list.length; i++) {
            const device = list[i];
            if (device.percent < 0)
                continue;
            if (!best || device.percent < best.percent)
                best = device;
        }
        if (!best)
            return null;
        return {
            fraction: Math.max(0, Math.min(1, best.percent / 100)),
            charging: best.state === "charging" || best.state === "full"
        };
    }
    readonly property int percent: Math.round((batt.charge?.fraction ?? 0) * 100)
    readonly property color ink: batt.percent <= DeviceBatteries.criticalLevel ? "#ff5c5c" : batt.colour

    implicitWidth: batt.charge ? batt.iconBox : profileIcon.implicitWidth
    implicitHeight: batt.charge ? batt.iconBox : profileIcon.implicitHeight

    Component.onCompleted: DeviceBatteries.refresh()

    MaterialIcon {
        id: profileIcon

        visible: !batt.charge
        anchors.centerIn: parent
        pointSizeScale: Config.barThicknessScale
        animate: true
        text: {
            if (PowerProfiles.profile === PowerProfile.PowerSaver)
                return "energy_savings_leaf";
            if (PowerProfiles.profile === PowerProfile.Performance)
                return "rocket_launch";
            return "balance";
        }
        color: batt.colour
        fill: 1
    }

    Item {
        id: glyph

        visible: !!batt.charge
        anchors.centerIn: parent
        width: Math.round(batt.iconBox * 0.58)
        height: batt.iconBox

        Rectangle {
            id: cap

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Math.round(parent.width * 0.46)
            height: Math.max(2, Math.round(batt.iconBox * 0.1))
            radius: height / 2
            color: batt.ink
        }

        Rectangle {
            id: shell

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cap.bottom
            anchors.topMargin: 1
            anchors.bottom: parent.bottom
            radius: Math.max(2, Math.round(batt.iconBox * 0.14))
            color: Qt.alpha(batt.ink, 0.22)
            border.width: Math.max(1, Math.round(batt.iconBox * 0.06))
            border.color: batt.ink

            Item {
                id: cavity

                anchors.fill: parent
                anchors.margins: shell.border.width
                clip: true

                Rectangle {
                    width: cavity.width
                    height: cavity.height * (batt.charge?.fraction ?? 0)
                    y: cavity.height - height
                    color: batt.ink

                    Behavior on height {
                        Anim {}
                    }
                }
            }
        }

        MaterialIcon {
            anchors.centerIn: shell
            visible: batt.charge?.charging ?? false
            text: "bolt"
            pointSizeScale: 0.42 * Config.barThicknessScale
            color: (batt.charge?.fraction ?? 0) > 0.55 ? Colours.palette.m3surface : batt.ink
            fill: 1
        }
    }
}
