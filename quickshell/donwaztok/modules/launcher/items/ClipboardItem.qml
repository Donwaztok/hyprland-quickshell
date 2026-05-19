import qs.components
import qs.services.shell
import qs.config
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
    readonly property string decodePath: `/tmp/quickshell/media/cliphist/donwaztok-${root.entryNumber}`

    readonly property real verticalPadding: Appearance.padding.smaller * 2
    readonly property real previewMaxHeight: Config.launcher.sizes.clipboardImagePreviewHeight
    readonly property real previewMaxWidth: {
        const rowWidth = root.width > 0 ? root.width : Config.launcher.sizes.itemWidth;
        const iconWidth = icon.implicitWidth > 0 ? icon.implicitWidth : 24;
        return Math.max(0, rowWidth - 24 - iconWidth - Appearance.spacing.normal);
    }

    readonly property var imageSourceSize: {
        if (previewImg.status === Image.Ready && previewImg.sourceSize.width > 0)
            return previewImg.sourceSize;
        const match = root.modelData.match(/(\d+)x(\d+)/);
        if (!match)
            return Qt.size(0, 0);
        return Qt.size(parseInt(match[1]), parseInt(match[2]));
    }

    readonly property real scaledPreviewWidth: {
        const srcW = root.imageSourceSize.width;
        const srcH = root.imageSourceSize.height;
        if (srcW <= 0 || srcH <= 0 || root.previewMaxWidth <= 0)
            return 0;
        const scale = Math.min(root.previewMaxWidth / srcW, root.previewMaxHeight / srcH);
        return srcW * scale;
    }

    readonly property real scaledPreviewHeight: {
        const srcW = root.imageSourceSize.width;
        const srcH = root.imageSourceSize.height;
        if (srcW <= 0 || srcH <= 0 || root.previewMaxWidth <= 0)
            return Config.launcher.sizes.itemHeight - root.verticalPadding;
        const scale = Math.min(root.previewMaxWidth / srcW, root.previewMaxHeight / srcH);
        return srcH * scale;
    }

    implicitHeight: {
        if (!root.isImage)
            return Config.launcher.sizes.itemHeight;
        return root.verticalPadding + root.scaledPreviewHeight;
    }

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: 0

        function onClicked(): void {
            Cliphist.copy(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    readonly property bool selected: ListView.isCurrentItem

    Item {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: Appearance.padding.smaller
        anchors.bottomMargin: Appearance.padding.smaller

        property string decodedImageSource: ""

        MaterialIcon {
            id: icon

            text: root.isImage ? "image" : "content_paste"
            font.pointSize: Appearance.font.size.extraLarge
            color: root.selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { CAnim {} }
        }

        Process {
            id: decodeProc
            command: ["bash", "-c", `[ -f '${root.decodePath}' ] || printf '${StringUtils.shellSingleQuoteEscape(root.modelData)}' | ${Cliphist.cliphistBinary} decode > '${root.decodePath}'`]
            Component.onCompleted: if (root.isImage) running = true
            onExited: (exitCode) => {
                if (exitCode === 0)
                    row.decodedImageSource = root.decodePath;
            }
        }

        Item {
            id: imagePreview
            visible: root.isImage && row.decodedImageSource.length > 0
            clip: true

            anchors.left: icon.right
            anchors.leftMargin: Appearance.spacing.normal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.scaledPreviewHeight

            Image {
                id: previewImg
                anchors.centerIn: parent
                width: root.scaledPreviewWidth
                height: root.scaledPreviewHeight
                source: row.decodedImageSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }
        }

        StyledText {
            id: label

            visible: !root.isImage
            text: StringUtils.cleanCliphistEntry(root.modelData).slice(0, 200) + (root.modelData.length > 200 ? "…" : "")
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.Normal
            color: root.selected ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurface, 0.55)
            elide: Text.ElideRight

            Behavior on color { CAnim {} }

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
