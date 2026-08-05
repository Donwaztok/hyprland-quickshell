import qs.services
import QtQuick
import qs.modules.shell.onScreenDisplay

OsdValueIndicator {
    id: osdValues
    value: Audio.sink?.audio.volume ?? 0
    icon: Audio.sink?.audio.muted ? "volume_off" : "volume_up"
    name: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : qsTr("Volume")
}
