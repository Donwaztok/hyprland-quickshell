pragma Singleton

import donwaztok.config
import Quickshell
import QtQuick

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/donwaztok`

    readonly property string notifimagecache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/donwaztok/imagecache/notifs`
    readonly property string wallsdir: Quickshell.env("DONWAZTOK_WALLPAPERS_DIR") || absolutePath(Config.paths.wallpaperDir)

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        if (path.startsWith("root:/")) {
            const subpath = path.slice(6);
            if (subpath.startsWith("assets/"))
                return Quickshell.shellPath("donwaztok/" + subpath);
            return Quickshell.shellPath(subpath);
        }
        return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
