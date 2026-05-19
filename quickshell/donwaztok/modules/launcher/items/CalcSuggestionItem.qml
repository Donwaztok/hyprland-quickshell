import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var modelData
    required property StyledTextField search
    property int bottomRadius: 0

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool isLastItem: root.modelData?.isLast === true

    implicitHeight: Config.launcher.sizes.itemHeight
    width: parent?.width ?? implicitWidth

    StateLayer {
        radius: 0
        rect.bottomLeftRadius: root.isLastItem ? root.bottomRadius : 0
        rect.bottomRightRadius: root.isLastItem ? root.bottomRadius : 0

        function onClicked(): void {
            Qalculator.applySuggestion(root.search, root.modelData.snippet);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        MaterialIcon {
            text: "functions"
            font.pointSize: Appearance.font.size.large
            color: root.selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.55)
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { CAnim {} }
        }

        StyledText {
            text: root.modelData.snippet
            font.pointSize: Appearance.font.size.normal
            font.family: Appearance.font.family.mono
            color: root.selected ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurface, 0.55)
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { CAnim {} }
        }

        StyledText {
            text: root.modelData.desc
            font.pointSize: Appearance.font.size.normal
            color: root.selected ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.85)
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { CAnim {} }
        }
    }
}
