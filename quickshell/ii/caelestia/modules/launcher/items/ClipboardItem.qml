import "../services"
import caelestia.components
import caelestia.services
import caelestia.config
import qs.services
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    required property string modelData
    required property var list
    required property var visibilities

    readonly property bool isImage: Cliphist.entryIsImage(root.modelData)
    readonly property int entryNumber: {
        const match = root.modelData.match(/^(\d+)\t/);
        return match ? parseInt(match[1]) : 0;
    }
    readonly property string decodePath: `/tmp/quickshell/media/cliphist/caelestia-${root.entryNumber}`

    readonly property real imagePreviewHeight: 88
    implicitHeight: root.isImage ? root.imagePreviewHeight : Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            Cliphist.copy(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    Item {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.larger
        anchors.rightMargin: Appearance.padding.larger
        anchors.margins: Appearance.padding.smaller

        property string decodedImageSource: ""

        MaterialIcon {
            id: icon

            text: root.isImage ? "image" : "content_paste"
            font.pointSize: Appearance.font.size.extraLarge
            color: Colours.palette.m3onSurfaceVariant

            anchors.verticalCenter: parent.verticalCenter
        }

        Process {
            id: decodeProc
            command: ["bash", "-c", `[ -f '${root.decodePath}' ] || printf '${StringUtils.shellSingleQuoteEscape(root.modelData)}' | ${Cliphist.cliphistBinary} decode > '${root.decodePath}'`]
            Component.onCompleted: if (root.isImage) running = true
            onExited: if (exitCode === 0) row.decodedImageSource = root.decodePath
        }

        Item {
            id: imagePreview
            visible: root.isImage && previewImg.source.toString().length > 0
            clip: true

            anchors.left: icon.right
            anchors.leftMargin: Appearance.spacing.normal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.imagePreviewHeight

            Image {
                id: previewImg
                anchors.fill: parent
                source: row.decodedImageSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        StyledText {
            id: label

            visible: !root.isImage
            text: StringUtils.cleanCliphistEntry(root.modelData).slice(0, 200) + (root.modelData.length > 200 ? "…" : "")
            font.pointSize: Appearance.font.size.normal
            elide: Text.ElideRight

            anchors.left: icon.right
            anchors.right: parent.right
            anchors.leftMargin: Appearance.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Component.onDestruction: {
        if (root.isImage && decodeProc.exitCode === 0)
            Quickshell.execDetached(["rm", "-f", root.decodePath]);
    }
}
