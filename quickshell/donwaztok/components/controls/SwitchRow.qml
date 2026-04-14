import ".."
import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property string label
    required property bool checked
    property bool enabled: true
    /** Flat list row: no nested card (use inside `PreferencesGroup` / `SectionContainer`). Default on — avoids “card in card”. */
    property bool flatStyle: true
    property var onToggled: function (checked) {}

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + (root.flatStyle ? Appearance.padding.normal * 2 : Appearance.padding.large * 2)
    radius: root.flatStyle ? 0 : 12
    color: root.flatStyle ? "transparent" : Colours.shellSurface
    border.width: root.flatStyle ? 0 : 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, root.flatStyle ? 0 : 0.38)

    Behavior on implicitHeight {
        Anim {}
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.flatStyle ? Appearance.padding.normal : Appearance.padding.large
        anchors.rightMargin: root.flatStyle ? Appearance.padding.normal : Appearance.padding.large
        anchors.topMargin: Appearance.padding.smaller
        anchors.bottomMargin: Appearance.padding.smaller
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: root.label
        }

        StyledSwitch {
            checked: root.checked
            enabled: root.enabled
            onToggled: {
                root.onToggled(checked);
            }
        }
    }
}
