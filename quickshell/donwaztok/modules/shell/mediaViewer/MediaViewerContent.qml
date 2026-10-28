pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts

Item {
    id: root

    signal requestClose
    signal requestFullscreen

    property string filePath: ""
    property real zoom: 0 // 0 = fit to window
    property bool fullscreen: false
    property bool chromeShown: false

    readonly property var imageExts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "ico", "avif", "tif", "tiff"]
    readonly property var playExts: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "mpg", "mpeg", "ogv", "wmv", "flv",
        "mp3", "flac", "ogg", "oga", "opus", "wav", "m4a", "aac"]

    readonly property string fileName: TextEditorService.fileName(root.filePath)
    readonly property string ext: {
        const dot = root.fileName.lastIndexOf(".");
        return dot > 0 ? root.fileName.slice(dot + 1).toLowerCase() : "";
    }
    readonly property bool isPlayable: root.playExts.indexOf(root.ext) >= 0
    readonly property string windowTitle: `${root.fileName || qsTr("Nothing open")} — Media`

    readonly property var video: root.isPlayable ? videoLoader.item : null
    readonly property bool videoPlaying: !!root.video && root.video.playing
    readonly property bool chromeVisible: winHover.hovered && (root.chromeShown || barHover.hovered || (root.isPlayable && !root.videoPlaying))

    readonly property real fitScale: img.implicitWidth > 0 && img.implicitHeight > 0
        ? Math.min(1, flick.width / img.implicitWidth, flick.height / img.implicitHeight) : 1
    readonly property real viewScale: root.zoom > 0 ? root.zoom : root.fitScale

    readonly property int index: {
        folder.count;
        for (let i = 0; i < folder.count; ++i) {
            if (folder.get(i, "filePath") === root.filePath)
                return i;
        }
        return -1;
    }

    onFilePathChanged: root.zoom = 0

    function fileUrl(path: string): string {
        return path.length ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    function step(delta: int): void {
        const n = folder.count;
        if (!n || (n === 1 && root.index === 0))
            return;
        const i = root.index < 0 ? 0 : (root.index + delta + n) % n;
        root.filePath = folder.get(i, "filePath");
    }

    function zoomAt(factor: real, px: real, py: real): void {
        const old = root.viewScale;
        const next = Math.max(Math.min(root.fitScale, 0.1), Math.min(20, old * factor));
        const cx = flick.contentX + px - img.x;
        const cy = flick.contentY + py - img.y;
        root.zoom = next;
        flick.contentX = cx * next / old + img.x - px;
        flick.contentY = cy * next / old + img.y - py;
        flick.returnToBounds();
    }

    function formatTime(ms: real): string {
        const s = Math.floor(Math.max(0, ms) / 1000);
        const h = Math.floor(s / 3600);
        const mm = String(Math.floor(s / 60) % 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${mm.padStart(2, "0")}:${ss}` : `${mm}:${ss}`;
    }

    FolderListModel {
        id: folder
        folder: root.fileUrl(root.filePath.slice(0, root.filePath.lastIndexOf("/")) || "/")
        showDirs: false
        caseSensitive: false
        nameFilters: root.imageExts.concat(root.playExts).map(e => `*.${e}`)
    }

    HoverHandler {
        id: winHover
        onPointChanged: {
            root.chromeShown = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.chromeShown = false
    }

    Shortcut {
        sequences: [StandardKey.Close, "Ctrl+W"]
        onActivated: root.requestClose()
    }
    Shortcut {
        sequences: ["Escape"]
        onActivated: root.fullscreen ? root.requestFullscreen() : root.requestClose()
    }
    Shortcut {
        sequences: ["F", "F11"]
        onActivated: root.requestFullscreen()
    }
    Shortcut {
        sequences: ["Right", "PgDown"]
        onActivated: root.isPlayable ? root.video?.seek(5000) : root.step(1)
    }
    Shortcut {
        sequences: ["Left", "PgUp"]
        onActivated: root.isPlayable ? root.video?.seek(-5000) : root.step(-1)
    }
    Shortcut {
        sequences: ["Ctrl+Right"]
        onActivated: root.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+Left"]
        onActivated: root.step(-1)
    }
    Shortcut {
        sequences: ["Space"]
        enabled: root.isPlayable
        onActivated: root.video?.toggle()
    }
    Shortcut {
        sequences: ["M"]
        enabled: root.isPlayable
        onActivated: root.video?.toggleMute()
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "+", "="]
        enabled: !root.isPlayable
        onActivated: root.zoomAt(1.25, flick.width / 2, flick.height / 2)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut, "-"]
        enabled: !root.isPlayable
        onActivated: root.zoomAt(0.8, flick.width / 2, flick.height / 2)
    }
    Shortcut {
        sequences: ["0"]
        enabled: !root.isPlayable
        onActivated: root.zoom = 0
    }
    Shortcut {
        sequences: ["1"]
        enabled: !root.isPlayable
        onActivated: root.zoomAt(1 / root.viewScale, flick.width / 2, flick.height / 2)
    }

    component BarButton: Item {
        id: btn
        property string icon: ""
        property string tip: ""
        signal clicked
        implicitWidth: 36
        implicitHeight: 36
        opacity: btn.enabled ? 1 : 0.38

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            color: Colours.palette.m3onSurface
        }

        StateLayer {
            enabled: btn.enabled
            radius: Appearance.rounding.full
            function onClicked(): void {
                btn.clicked();
            }
            QC.ToolTip.visible: containsMouse && btn.tip.length > 0
            QC.ToolTip.delay: 400
            QC.ToolTip.text: btn.tip
        }
    }

    // Image -----------------------------------------------------------------

    Flickable {
        id: flick
        anchors.fill: parent
        visible: !root.isPlayable
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: Math.max(width, img.width)
        contentHeight: Math.max(height, img.height)

        Item {
            id: img
            readonly property Item view: imgLoader.item
            implicitWidth: img.view ? img.view.implicitWidth : 0
            implicitHeight: img.view ? img.view.implicitHeight : 0
            width: img.implicitWidth * root.viewScale
            height: img.implicitHeight * root.viewScale
            x: Math.max(0, (flick.width - width) / 2)
            y: Math.max(0, (flick.height - height) / 2)

            Loader {
                id: imgLoader
                anchors.fill: parent
                active: !root.isPlayable && root.filePath.length > 0
                sourceComponent: root.ext === "gif" || root.ext === "webp" ? animatedImage : stillImage
            }
        }
    }

    MouseArea {
        anchors.fill: flick
        visible: flick.visible
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            root.zoomAt(wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15, wheel.x, wheel.y);
            wheel.accepted = true;
        }

        TapHandler {
            onDoubleTapped: point => {
                if (root.zoom > 0)
                    root.zoom = 0;
                else
                    root.zoomAt(1 / root.viewScale, point.position.x, point.position.y);
            }
        }
    }

    Component {
        id: stillImage
        Image {
            // Full-resolution decode on purpose: the viewer zooms to 100% and beyond.
            source: root.fileUrl(root.filePath)
            asynchronous: true
            smooth: root.viewScale < 2
            mipmap: root.viewScale < 1
            autoTransform: true
        }
    }

    Component {
        id: animatedImage
        AnimatedImage {
            source: root.fileUrl(root.filePath)
            smooth: root.viewScale < 2
        }
    }

    CircularIndicator {
        anchors.centerIn: parent
        running: visible
        visible: !root.isPlayable && !!imgLoader.item && imgLoader.item.status === Image.Loading
    }

    // Video / audio ---------------------------------------------------------

    Loader {
        id: videoLoader
        anchors.fill: parent
        active: root.isPlayable
        // Separate file so a missing QtMultimedia only breaks playback, not the shell.
        source: "VideoView.qml"
        onLoaded: item.source = root.fileUrl(root.filePath)
    }

    Connections {
        target: root.video
        function onDoubleTapped(): void {
            root.requestFullscreen();
        }
    }

    Connections {
        target: root
        enabled: !!root.video
        function onFilePathChanged(): void {
            if (root.isPlayable)
                root.video.source = root.fileUrl(root.filePath);
        }
    }

    // Empty and error states --------------------------------------------------

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.small
        visible: message.text.length > 0

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.filePath.length ? "broken_image" : "image"
            color: root.filePath.length ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.extraLarge * 1.5
        }

        StyledText {
            id: message
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width - Appearance.padding.large * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
            text: {
                if (!root.filePath.length)
                    return qsTr("Nothing open");
                if (root.isPlayable) {
                    if (videoLoader.status === Loader.Error)
                        return qsTr("Video playback needs qt6-multimedia and qt6-multimedia-ffmpeg");
                    return root.video?.errorText ?? "";
                }
                if (imgLoader.item && imgLoader.item.status === Image.Error)
                    return qsTr("Could not open %1").arg(root.fileName);
                return "";
            }
        }
    }

    // Bottom bar ----------------------------------------------------------------

    StyledRect {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.large
        width: root.isPlayable ? Math.min(root.width - Appearance.padding.large * 2, 720) : barRow.implicitWidth
            + Appearance.padding.small * 2
        implicitHeight: barRow.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.full
        color: Colours.tPalette.m3surfaceContainer
        visible: root.filePath.length > 0 && (!root.isPlayable || !!root.video)
        opacity: root.chromeVisible ? 1 : 0

        Behavior on opacity {
            Anim {}
        }

        HoverHandler {
            id: barHover
        }

        RowLayout {
            id: barRow
            anchors.fill: parent
            anchors.margins: Appearance.padding.small
            spacing: Appearance.spacing.small

            BarButton {
                icon: "chevron_left"
                tip: qsTr("Previous")
                enabled: folder.count > 1
                onClicked: root.step(-1)
            }

            BarButton {
                visible: root.isPlayable
                icon: root.videoPlaying ? "pause" : "play_arrow"
                tip: root.videoPlaying ? qsTr("Pause") : qsTr("Play")
                onClicked: root.video.toggle()
            }

            StyledText {
                visible: root.isPlayable
                text: root.video ? root.formatTime(root.video.position) : ""
                color: Colours.palette.m3onSurfaceVariant
                font.family: Appearance.font.family.mono
            }

            StyledSlider {
                visible: root.isPlayable
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, root.video?.duration ?? 1)
                value: root.video?.position ?? 0
                enabled: root.video?.seekable ?? false
                onMoved: root.video.position = value
            }

            StyledText {
                visible: root.isPlayable
                text: root.video ? root.formatTime(root.video.duration) : ""
                color: Colours.palette.m3onSurfaceVariant
                font.family: Appearance.font.family.mono
            }

            BarButton {
                visible: root.isPlayable
                icon: root.video?.muted ? "volume_off" : "volume_up"
                tip: root.video?.muted ? qsTr("Unmute") : qsTr("Mute")
                onClicked: root.video.toggleMute()
            }

            StyledText {
                visible: folder.count > 1 && root.index >= 0
                text: `${root.index + 1} / ${folder.count}`
                color: Colours.palette.m3onSurfaceVariant
            }

            BarButton {
                visible: !root.isPlayable
                icon: root.zoom > 0 ? "fit_screen" : "zoom_in"
                tip: root.zoom > 0 ? qsTr("Fit to window") : qsTr("Actual size")
                onClicked: root.zoom > 0 ? root.zoom = 0 : root.zoomAt(1 / root.viewScale, flick.width / 2,
                    flick.height / 2)
            }

            StyledText {
                visible: !root.isPlayable && img.implicitWidth > 0
                text: `${Math.round(root.viewScale * 100)}%`
                color: Colours.palette.m3onSurfaceVariant
                Layout.minimumWidth: 44
                horizontalAlignment: Text.AlignHCenter
            }

            BarButton {
                icon: "chevron_right"
                tip: qsTr("Next")
                enabled: folder.count > 1
                onClicked: root.step(1)
            }
        }
    }
}
