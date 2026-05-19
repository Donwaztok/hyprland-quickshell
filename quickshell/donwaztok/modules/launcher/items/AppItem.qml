import qs.modules.launcher.services
import qs.components
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property DesktopEntry modelData
    required property PersistentProperties visibilities

    readonly property bool selected: ListView.isCurrentItem

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: 0

        function onClicked(): void {
            Apps.launch(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        IconImage {
            id: icon

            readonly property int iconSize: 28

            visible: !!source
            source: root.modelData ? Quickshell.iconPath(root.modelData.icon || root.modelData.id, "application-x-executable") : ""
            implicitSize: iconSize
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: iconSize
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            id: name

            Layout.fillWidth: true
            text: root.modelData?.name ?? ""
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.Normal
            color: root.selected ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurface, 0.55)
            elide: Text.ElideRight

            Behavior on color { CAnim {} }
        }

        Loader {
            id: favouriteIcon

            Layout.alignment: Qt.AlignVCenter
            active: modelData && Strings.testRegexList(Config.launcher.favouriteApps, modelData.id)

            sourceComponent: MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }
}
