import caelestia.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    id: root
    required property string materialSymbol
    required property bool current
    horizontalPadding: 10

    implicitHeight: 40
    implicitWidth: implicitContentWidth + horizontalPadding * 2
    buttonRadius: height / 2

    colBackground: ColorUtils.transparentize(Colours.tPalette.m3surfaceContainer)
    colBackgroundHover: current
        ? ColorUtils.transparentize(Colours.tPalette.m3onPrimary, 0.88)
        : ColorUtils.transparentize(Colours.tPalette.m3onSurface, 0.95)
    colRipple: current
        ? ColorUtils.transparentize(Colours.tPalette.m3onPrimary, 0.92)
        : ColorUtils.transparentize(Colours.tPalette.m3onSurface, 0.95)

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
            color: root.current ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurfaceVariant
        }
        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.current ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurfaceVariant
        }
    }
}
