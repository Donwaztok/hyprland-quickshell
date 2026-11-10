import qs.components
import qs.services.shell
import qs.config
import qs.utils
import QtQuick

MaterialIcon {
    property color colour
    property bool inTray

    color: colour

    pointSizeScale: Config.barThicknessScale
    animate: true
    text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
}
