pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.services.shell
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * File-manager thumbnail:
 * - Qt-native images load directly
 * - webp/avif/jxl/ico via magick → PNG cache
 * - Windows .exe/.dll via PE icon extract
 * - AppImage / .desktop / Linux bins via fm.py → PNG cache
 */
Item {
    id: root

    property var entry: null
    property real implicitSize: 28

    readonly property string filePath: entry && entry.path ? String(entry.path) : ""
    readonly property string suffix: entry && entry.suffix ? String(entry.suffix).toLowerCase() : ""
    readonly property string thumbKind: {
        if (entry && entry.thumbKind)
            return String(entry.thumbKind);
        const s = root.suffix;
        if (s === "exe" || s === "dll")
            return "exe";
        if (s === "appimage")
            return "appimage";
        if (s === "desktop")
            return "desktop";
        if (s === "webp" || s === "avif" || s === "jxl" || s === "ico")
            return "convert";
        return "image";
    }
    readonly property bool useConvert: root.thumbKind === "convert" || root.suffix === "webp" || root.suffix === "avif" || root.suffix === "jxl" || root.suffix === "ico"
    readonly property bool useExtract: ["exe", "appimage", "desktop", "linux"].indexOf(root.thumbKind) >= 0
        || root.suffix === "exe" || root.suffix === "dll" || root.suffix === "appimage" || root.suffix === "desktop"
    readonly property bool useNative: !root.useConvert && !root.useExtract && root.filePath.length > 0
    readonly property string fallbackGlyph: {
        if (root.thumbKind === "appimage" || (entry && entry.isAppImage))
            return "deployed_code";
        if (root.thumbKind === "desktop" || root.suffix === "desktop")
            return "widgets";
        if (root.thumbKind === "linux")
            return "terminal";
        if (root.useExtract)
            return "grid_view";
        return "image";
    }
    readonly property string cachePath: {
        if (!root.filePath.length || (!root.useConvert && !root.useExtract))
            return "";
        const key = Qt.md5(root.filePath + ":" + Math.round(root.implicitSize) + ":" + root.thumbKind);
        return `${Paths.state}/fm-thumbs/${key}.png`;
    }

    property bool failed: false

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    CachingIconImage {
        anchors.fill: parent
        implicitSize: root.implicitSize
        visible: root.useNative && !root.failed
        source: visible ? Qt.resolvedUrl("file://" + root.filePath) : ""
    }

    Image {
        id: converted
        anchors.fill: parent
        visible: (root.useConvert || root.useExtract) && status === Image.Ready
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        source: ""
        cache: true
        smooth: true
        onStatusChanged: {
            if (status === Image.Ready) {
                root.failed = false;
                return;
            }
            // Clearing source emits Error — ignore empty/null sources
            if (status === Image.Error && (root.useConvert || root.useExtract) && source.toString().length > 0)
                root.failed = true;
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        // Only while loading / failed — never over a ready preview
        visible: (root.useConvert || root.useExtract) && converted.status !== Image.Ready
        text: root.fallbackGlyph
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Math.max(12, root.implicitSize * 0.55)
    }

    Process {
        id: thumbProc
        running: false
        command: ["true"]
        onExited: code => {
            if (code !== 0 || !root.cachePath.length) {
                root.failed = true;
                return;
            }
            const url = Qt.resolvedUrl("file://" + root.cachePath);
            converted.source = "";
            converted.source = url;
        }
    }

    onFilePathChanged: root.kick()
    onCachePathChanged: root.kick()
    Component.onCompleted: root.kick()

    function kick(): void {
        root.failed = false;
        converted.source = "";
        thumbProc.running = false;
        if (!root.filePath.length)
            return;

        if (root.useNative)
            return;

        if (!root.cachePath.length)
            return;

        const px = Math.max(32, Math.round(root.implicitSize * 2));
        if (root.useExtract || root.useConvert) {
            thumbProc.command = [
                FileManagerService.binary,
                "thumb",
                root.filePath,
                root.cachePath,
                "--size",
                String(px)
            ];
            thumbProc.running = true;
        }
    }
}
