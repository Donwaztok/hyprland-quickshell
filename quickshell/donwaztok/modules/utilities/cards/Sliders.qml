pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var screen

    readonly property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : Brightness.getMonitor("active")
    readonly property bool brightnessAvailable: {
        const monitor = brightnessMonitor;
        if (!monitor)
            return false;
        return monitor.isDdc || monitor.isAppleDisplay || Brightness.hasBacklight;
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        MeterRow {
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            value: Audio.volume
            to: Config.services.maxVolume
            muted: Audio.muted
            iconClickable: true

            onMoved: v => {
                Audio.setVolume(v);
                if (Audio.muted && Audio.sink?.audio)
                    Audio.sink.audio.muted = false;
            }
            onIconClicked: {
                if (Audio.sink?.audio)
                    Audio.sink.audio.muted = !Audio.sink.audio.muted;
            }
            onWheelUp: Audio.incrementVolume()
            onWheelDown: Audio.decrementVolume()
        }

        MeterRow {
            visible: root.brightnessAvailable
            icon: Icons.getBrightnessIcon(root.brightnessMonitor?.brightness ?? 0)
            value: root.brightnessMonitor?.brightness ?? 0
            to: 1

            onMoved: v => root.brightnessMonitor?.setBrightness(v)
            onWheelUp: {
                const monitor = root.brightnessMonitor;
                if (monitor)
                    monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
            }
            onWheelDown: {
                const monitor = root.brightnessMonitor;
                if (monitor)
                    monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
            }
        }
    }

    component MeterRow: RowLayout {
        id: meter

        required property string icon
        property real value: 0
        property real to: 1
        property bool muted: false
        property bool iconClickable: false

        signal moved(real value)
        signal iconClicked
        signal wheelUp
        signal wheelDown

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Item {
            implicitWidth: iconBtn.implicitWidth
            implicitHeight: iconBtn.implicitHeight

            IconButton {
                id: iconBtn

                anchors.centerIn: parent
                type: IconButton.Text
                icon: meter.icon
                toggle: false
                inactiveOnColour: meter.muted ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                onClicked: {
                    if (meter.iconClickable)
                        meter.iconClicked();
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: slider.implicitHeight

            StyledSlider {
                id: slider

                anchors.fill: parent
                value: meter.value
                from: 0
                to: meter.to
                opacity: meter.muted ? 0.45 : 1
                onMoved: meter.moved(value)

                Behavior on opacity {
                    Anim {}
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        meter.wheelUp();
                    else if (event.angleDelta.y < 0)
                        meter.wheelDown();
                    event.accepted = true;
                }
            }
        }

        StyledText {
            id: percentLabel

            Layout.preferredWidth: percentMetrics.advanceWidth
            Layout.minimumWidth: percentMetrics.advanceWidth
            text: `${Math.round(meter.value * 100)}%`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
            horizontalAlignment: Text.AlignRight
        }

        TextMetrics {
            id: percentMetrics

            font: percentLabel.font
            text: `${Math.round(meter.to * 100)}%`
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
