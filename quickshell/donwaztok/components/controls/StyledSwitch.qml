import ".."
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Templates

Switch {
    id: root

    property int cLayer: 1

    /** Avoid extra insets from the template shifting the indicator inside the control. */
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    implicitWidth: implicitIndicatorWidth
    implicitHeight: implicitIndicatorHeight

    indicator: Item {
        id: trackRoot

        /** Integer geometry avoids half-pixel vertical drift (thumb looked “low” in the track). */
        readonly property int inset: Math.max(1, Math.round(Appearance.padding.small / 2))
        readonly property int trackH: {
            const raw = Math.round(Appearance.font.size.normal + Appearance.padding.smaller * 2);
            return Math.max(18, raw | 0);
        }

        implicitHeight: trackH
        implicitWidth: Math.round(trackH * 1.7)

        readonly property color onTrack: Colours.palette.m3primary
        readonly property color offTrack: Colours.light
            ? Colours.palette.m3outlineVariant
            : Colours.palette.m3surfaceContainerHighest

        StyledRect {
            id: trackBg

            anchors.fill: parent
            radius: Appearance.rounding.full
            color: root.checked ? trackRoot.onTrack : trackRoot.offTrack
            border.width: 0

            StyledRect {
                id: thumb

                readonly property int hPx: Math.max(1, Math.floor(trackBg.height > 0 ? trackBg.height : trackRoot.trackH))
                readonly property int knobSize: Math.max(1, hPx - 2 * trackRoot.inset)
                readonly property real knobW: root.pressed ? knobSize * 1.3 : knobSize

                radius: Appearance.rounding.full
                color: Colours.palette.m3onPrimary
                border.width: 0

                width: knobW
                height: knobSize
                x: root.checked ? trackBg.width - knobW - trackRoot.inset : trackRoot.inset
                y: Math.round((hPx - knobSize) / 2)

                Behavior on x {
                    Anim {}
                }

                Behavior on width {
                    Anim {}
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }
}
