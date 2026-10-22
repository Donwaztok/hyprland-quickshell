import qs.services
import QtQuick
import qs.modules.shell.onScreenDisplay

OsdValueIndicator {
    id: osdValues
    value: Audio.sink?.audio.volume ?? 0
    icon: Audio.sink?.audio.muted ? "volume_off" : value < 0.01 ? "volume_mute" : value < 0.5 ? "volume_down" : "volume_up"
    name: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : qsTr("Volume")
}
