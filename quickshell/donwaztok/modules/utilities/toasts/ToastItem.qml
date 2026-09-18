import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property Toast modelData

    readonly property bool isSuccess: root.modelData.type === Toast.Success
    readonly property bool isWarning: root.modelData.type === Toast.Warning
    readonly property bool isError: root.modelData.type === Toast.Error
    readonly property bool hasMessage: (root.modelData.message || "").length > 0
    readonly property int hPad: Appearance.padding.large
    readonly property int vPad: Appearance.padding.normal
    readonly property int maxTextWidth: Config.utilities.sizes.toastWidth - root.hPad * 2 - Appearance.spacing.normal - iconBox.implicitWidth

    implicitWidth: layout.implicitWidth + root.hPad * 2
    implicitHeight: layout.implicitHeight + root.vPad * 2

    radius: Appearance.rounding.full
    color: {
        if (root.isSuccess)
            return Colours.palette.m3successContainer;
        if (root.isWarning)
            return Colours.palette.m3secondaryContainer;
        if (root.isError)
            return Colours.palette.m3errorContainer;
        return Colours.layer(Colours.palette.m3surfaceContainer, 2);
    }

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 3
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.normal

        StyledRect {
            id: iconBox

            radius: Appearance.rounding.full
            color: {
                if (root.isSuccess)
                    return Colours.palette.m3success;
                if (root.isWarning)
                    return Colours.palette.m3secondary;
                if (root.isError)
                    return Colours.palette.m3error;
                return Colours.palette.m3primary;
            }

            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Appearance.padding.smaller * 2

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: root.modelData.icon
                fill: root.isSuccess || root.modelData.icon.endsWith("_badge") ? 1 : 0
                color: {
                    if (root.isSuccess)
                        return Colours.palette.m3onSuccess;
                    if (root.isWarning)
                        return Colours.palette.m3onSecondary;
                    if (root.isError)
                        return Colours.palette.m3onError;
                    return Colours.palette.m3onPrimary;
                }
                font.pointSize: Appearance.font.size.large
            }
        }

        ColumnLayout {
            Layout.maximumWidth: root.maxTextWidth
            spacing: 0

            StyledText {
                Layout.maximumWidth: root.maxTextWidth
                text: root.modelData.title
                color: {
                    if (root.isSuccess)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.isWarning)
                        return Colours.palette.m3onSecondaryContainer;
                    if (root.isError)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurface;
                }
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                Layout.maximumWidth: root.maxTextWidth
                visible: root.hasMessage
                textFormat: Text.StyledText
                text: root.modelData.message
                color: {
                    if (root.isSuccess)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.isWarning)
                        return Colours.palette.m3onSecondaryContainer;
                    if (root.isError)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurfaceVariant;
                }
                opacity: 0.85
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}
