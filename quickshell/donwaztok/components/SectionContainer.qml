import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    default property alias content: contentColumn.data
    property real contentSpacing: Appearance.spacing.normal
    property bool alignTop: false

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: ControlCenterChrome.settingsGroupCard
    border.width: 1
    border.color: ControlCenterChrome.settingsGroupCardBorder

    Elevation {
        z: -1
        anchors.fill: parent
        radius: parent.radius
        level: Colours.light ? 1 : 2
    }

    ColumnLayout {
        id: contentColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.alignTop ? parent.top : undefined
        anchors.verticalCenter: root.alignTop ? undefined : parent.verticalCenter
        anchors.margins: Appearance.padding.large

        spacing: root.contentSpacing
    }
}
