pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services.shell
import qs.config as Theme
import qs.utils
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import QtQuick.Window
import Quickshell

Item {
    id: root

    signal requestClose
    signal interacted

    property string startPath: FileManagerService.home
    property bool confirmDeleteOpen: false
    property bool confirmEmptyTrashOpen: false
    property bool propertiesOpen: false
    property bool propertiesBusy: false
    property var propertiesInfo: ({})
    property bool searchOpen: false
    readonly property bool renameOpen: session.renameTarget.length > 0
    readonly property bool dialogOpen: confirmDeleteOpen || confirmEmptyTrashOpen || propertiesOpen || root.renameOpen
    readonly property bool inputBlocked: session.pathEditing || root.renameOpen || searchField.activeFocus
    readonly property bool navBlocked: session.pathEditing || root.renameOpen
    readonly property bool renameBlocked: session.pathEditing || root.renameOpen || session.isTrashView
    readonly property bool isWindowActive: Window.active
    readonly property string currentPath: session.currentPath
    readonly property bool canGoBack: session.canGoBack
    readonly property bool canGoForward: session.canGoForward
    readonly property int historyCount: session.history.length
    property string lastInput: ""
    property double lastNavAt: 0
    // Collapse Places/Devices sidebar on narrow windows so the file list keeps space
    readonly property int sidebarBreakpoint: 820
    readonly property bool sidebarExpanded: width >= sidebarBreakpoint
    // Primary-tinted chrome (file selection / drop)
    readonly property color fmSelectBg: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.16 : 0.22)
    readonly property color fmHoverBg: Colours.tPalette.m3surfaceContainerHigh
    readonly property color fmDropBg: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.28 : 0.32)

    FileManagerSession {
        id: session
    }

    Connections {
        target: session
        function onCurrentPathChanged(): void {
            root.pushStatusToast();
        }
        function onSelectedPathsChanged(): void {
            root.pushStatusToast();
        }
        function onBusyChanged(): void {
            if (!session.busy)
                root.pushStatusToast();
        }
    }

    function claimFocus(): void {
        root.interacted();
        if (session.pathEditing || session.renameTarget.length > 0 || searchField.activeFocus)
            return;
        if (session.listView)
            fileList.forceActiveFocus();
        else
            fileGrid.forceActiveFocus();
    }

    function openAt(path: string): void {
        session.initAt(path && path.length ? path : FileManagerService.home);
        Qt.callLater(() => root.claimFocus());
    }

    Component.onCompleted: {
        if (!session.currentPath.length)
            session.initAt(root.startPath);
        Qt.callLater(() => root.claimFocus());
    }

    readonly property var pathCrumbs: session.pathCrumbs
    property bool fileDragActive: false
    property bool folderDragActive: false
    property var pendingDragItem: null
    property bool marqueeActive: false
    property bool marqueeMoved: false
    property bool marqueePending: false
    property bool marqueeAdditive: false
    property var marqueeBase: []
    property real marqueeOriginX: 0
    property real marqueeOriginY: 0
    property real marqueeX: 0
    property real marqueeY: 0
    readonly property real marqueeThreshold: 6
    property bool shiftHeld: false
    property bool ctrlHeld: false

    focus: true
    activeFocusOnTab: true
    Keys.priority: Keys.BeforeItem

    property int dragPreviewSeq: 0

    // Off-screen grab source for Drag.Automatic (compositor moves pixmap with cursor)
    StyledRect {
        id: dragGrabSource
        visible: true
        x: -4000
        y: -4000
        z: 4000
        width: 220
        height: 48
        radius: Theme.Appearance.rounding.normal
        color: Colours.palette.m3surfaceContainerHigh

        property string previewName: "File"
        property string previewIcon: "draft"
        property string previewPath: ""
        property bool previewIsImage: false
        property int previewCount: 1

        RowLayout {
            id: dragGrabRow
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.Appearance.padding.normal
            spacing: Theme.Appearance.spacing.small

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Image {
                    id: dragGrabThumb
                    anchors.fill: parent
                    visible: dragGrabSource.previewIsImage && status === Image.Ready
                    asynchronous: false
                    cache: false
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 72
                    sourceSize.height: 72
                    source: ""
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !dragGrabThumb.visible
                    text: dragGrabSource.previewIcon
                    color: Colours.palette.m3primary
                    font.pointSize: Theme.Appearance.font.size.large
                    fill: 1
                }
            }

            StyledText {
                text: dragGrabSource.previewName
                color: Colours.palette.m3onSurface
                elide: Text.ElideMiddle
                Layout.maximumWidth: 200
                font.weight: Font.Medium
            }

            StyledRect {
                visible: dragGrabSource.previewCount > 1
                implicitWidth: grabCountLabel.implicitWidth + 10
                implicitHeight: 20
                radius: Theme.Appearance.rounding.full
                color: Colours.palette.m3primary

                StyledText {
                    id: grabCountLabel
                    anchors.centerIn: parent
                    text: dragGrabSource.previewCount
                    color: Colours.palette.m3onPrimary
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Timer {
        id: dragGrabWait
        property var sourceItem: null
        property int seq: 0
        property int attempts: 0
        interval: 16
        repeat: false
        onTriggered: root.finishDragPreviewGrab(dragGrabWait.sourceItem, dragGrabWait.seq)
    }

    function beginFileDrag(sourceItem: var, entry: var, handler: var): void {
        if (!sourceItem || !entry)
            return;
        if (!session.isSelected(entry.path))
            session.selectOnly(entry.path);
        sourceItem.dragUris = session.uriListForDrag(entry.path);
        // Drop cached drag pixmap so the next imageSource is not reused
        sourceItem.Drag.imageSource = "";

        const suffix = String(entry.suffix || "").toLowerCase();
        const nativeImage = !!(entry.isImage) && suffix !== "webp" && suffix !== "avif" && suffix !== "jxl";

        dragGrabSource.previewName = entry.name || "";
        dragGrabSource.previewIcon = sourceItem.glyph || "draft";
        dragGrabSource.previewPath = entry.path || "";
        dragGrabSource.previewIsImage = nativeImage;
        dragGrabSource.previewCount = session.selectedPaths.length || 1;
        root.pendingDragItem = sourceItem;
        root.fileDragActive = true;
        root.folderDragActive = root.selectionHasFolder(entry);
        root.dragPreviewSeq += 1;
        const seq = root.dragPreviewSeq;

        dragGrabThumb.source = "";
        if (nativeImage && entry.path)
            dragGrabThumb.source = Qt.resolvedUrl("file://" + entry.path);

        dragGrabSource.x = -4000;
        dragGrabSource.y = -4000;
        dragGrabSource.visible = true;

        dragGrabWait.sourceItem = sourceItem;
        dragGrabWait.seq = seq;
        dragGrabWait.attempts = 0;
        dragGrabWait.restart();
    }

    function finishDragPreviewGrab(sourceItem: var, seq: int): void {
        if (!sourceItem || root.pendingDragItem !== sourceItem || seq !== root.dragPreviewSeq)
            return;

        // Wait for thumb decode on the first frame(s); fall back to icon quickly
        if (dragGrabSource.previewIsImage && dragGrabThumb.status === Image.Loading && dragGrabWait.attempts < 8) {
            dragGrabWait.attempts += 1;
            dragGrabWait.restart();
            return;
        }

        const padX = Theme.Appearance.padding.normal * 2;
        const padY = Theme.Appearance.padding.small * 2;
        const w = Math.min(280, Math.max(160, Math.round(dragGrabRow.implicitWidth + padX)));
        const h = Math.max(48, Math.round(dragGrabRow.implicitHeight + padY));
        dragGrabSource.width = w;
        dragGrabSource.height = h;

        dragGrabSource.grabToImage(result => {
            if (root.pendingDragItem !== sourceItem || seq !== root.dragPreviewSeq)
                return;
            let url = "";
            if (result) {
                // Unique path every drag — same file:// is cached by Qt Drag and looks "stuck"
                const path = "/tmp/donwaztok-fm-drag-" + seq + ".png";
                try {
                    if (result.saveToFile(path))
                        url = "file://" + path;
                } catch (e) {}
                if (!url.length && result.url)
                    url = result.url;
            }
            if (url.length)
                sourceItem.Drag.imageSource = url;
            sourceItem.Drag.hotSpot = Qt.point(20, Math.round(h / 2));
            sourceItem.Drag.active = true;
        }, Qt.size(w, h));
    }

    function endFileDrag(sourceItem: var): void {
        if (sourceItem) {
            sourceItem.Drag.active = false;
            sourceItem.Drag.imageSource = "";
        }
        root.fileDragActive = false;
        root.folderDragActive = false;
        root.pendingDragItem = null;
    }

    function hitFileAt(areaX: real, areaY: real): string {
        const view = session.listView ? fileList : fileGrid;
        if (!view || !view.visible || !view.contentItem)
            return "";
        const p = view.contentItem.mapFromItem(fileArea, areaX, areaY);
        const idx = view.indexAt(p.x, p.y);
        if (idx < 0)
            return "";
        const list = session.filteredEntries;
        if (idx >= list.length)
            return "";
        return list[idx].path || "";
    }

    function indexRectInArea(index: int): var {
        if (session.listView) {
            const yContent = index * (44 + fileList.spacing);
            const topLeft = fileArea.mapFromItem(fileList.contentItem, 0, yContent);
            return Qt.rect(topLeft.x, topLeft.y, fileList.width, 44);
        }
        const cols = Math.max(1, Math.floor(fileGrid.width / fileGrid.cellWidth));
        const col = index % cols;
        const row = Math.floor(index / cols);
        const topLeft = fileArea.mapFromItem(fileGrid.contentItem, col * fileGrid.cellWidth, row * fileGrid.cellHeight);
        return Qt.rect(topLeft.x, topLeft.y, fileGrid.cellWidth, fileGrid.cellHeight);
    }

    function rectsOverlap(a: var, b: var): bool {
        if (a.width <= 0 || a.height <= 0)
            return false;
        return a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y;
    }

    function pathsInMarquee(mx: real, my: real, cx: real, cy: real): var {
        const w = Math.abs(cx - mx);
        const h = Math.abs(cy - my);
        if (w < 1 || h < 1)
            return [];
        const rect = Qt.rect(Math.min(mx, cx), Math.min(my, cy), w, h);
        const list = session.filteredEntries;
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            if (root.rectsOverlap(rect, root.indexRectInArea(i)))
                out.push(list[i].path);
        }
        return out;
    }

    function beginMarquee(areaX: real, areaY: real, additive: bool): void {
        if (root.dialogOpen || session.renameTarget.length || session.pathEditing)
            return;
        root.marqueePending = false;
        root.marqueeActive = true;
        root.marqueeMoved = false;
        root.marqueeAdditive = additive;
        root.marqueeBase = additive ? session.selectedPaths.slice() : [];
        root.marqueeOriginX = areaX;
        root.marqueeOriginY = areaY;
        root.marqueeX = areaX;
        root.marqueeY = areaY;
        if (!additive)
            session.clearSelection();
        root.claimFocus();
    }

    function updateMarquee(areaX: real, areaY: real): void {
        if (!root.marqueeActive)
            return;
        root.marqueeX = areaX;
        root.marqueeY = areaY;
        const dx = areaX - root.marqueeOriginX;
        const dy = areaY - root.marqueeOriginY;
        if ((dx * dx + dy * dy) >= root.marqueeThreshold * root.marqueeThreshold)
            root.marqueeMoved = true;
        if (!root.marqueeMoved)
            return;
        session.applyMarqueeSelection(root.pathsInMarquee(root.marqueeOriginX, root.marqueeOriginY, areaX, areaY), root.marqueeAdditive, root.marqueeBase);
    }

    function endMarquee(): void {
        root.marqueePending = false;
        if (!root.marqueeActive)
            return;
        if (root.marqueeMoved)
            root.updateMarquee(root.marqueeX, root.marqueeY);
        root.marqueeActive = false;
        root.marqueeBase = [];
    }

    function consumeMarqueeClick(): bool {
        if (!root.marqueeMoved)
            return false;
        root.marqueeMoved = false;
        return true;
    }

    function mapToFileArea(item: var, x: real, y: real): var {
        return fileArea.mapFromItem(item, x, y);
    }

    function setShiftHeld(held: bool): void {
        root.shiftHeld = held;
    }

    function setCtrlHeld(held: bool): void {
        root.ctrlHeld = held;
    }

    function isShiftDown(mouseMods: int): bool {
        return !!(mouseMods & Qt.ShiftModifier) || root.shiftHeld;
    }

    function isCtrlDown(mouseMods: int): bool {
        return !!(mouseMods & Qt.ControlModifier) || root.ctrlHeld;
    }

    function clickSelectPath(path: string, mouseMods: int): void {
        if (!path || !path.length)
            return;
        if (root.isCtrlDown(mouseMods))
            session.toggleSelect(path);
        else if (root.isShiftDown(mouseMods))
            session.selectRange(path);
        else
            session.selectOnly(path);
    }

    function navigateTo(path: string): void {
        session.navigate(path);
    }

    function fileGlyph(f: var): string {
        if (!f)
            return "draft";
        if (f.isDir)
            return "folder";
        if (f.isAppImage)
            return "deployed_code";
        if (f.isDesktop || String(f.suffix || "").toLowerCase() === "desktop")
            return "widgets";
        if (f.isArchive)
            return "folder_zip";
        if (f.isImage)
            return "image";
        if (f.isWindowsExe)
            return "grid_view";
        if (f.isLinuxBin)
            return "terminal";

        const name = String(f.name || "").toLowerCase();
        const suffix = String(f.suffix || "").toLowerCase();
        const mime = String(f.mimeType || "");

        if (suffix === "pdf" || mime === "application/pdf")
            return "picture_as_pdf";
        if (suffix === "csv")
            return "table";
        if (["xls", "xlsx", "ods"].indexOf(suffix) >= 0)
            return "table_chart";
        if (["doc", "docx", "odt", "rtf"].indexOf(suffix) >= 0)
            return "article";
        if (["ppt", "pptx", "odp"].indexOf(suffix) >= 0)
            return "slideshow";
        if (suffix === "epub" || suffix === "mobi" || suffix === "azw3")
            return "menu_book";
        if (suffix === "torrent")
            return "download";
        if (suffix === "iso" || suffix === "img" || suffix === "vhd" || suffix === "vmdk")
            return "album";
        if (suffix === "apk")
            return "android";
        if (suffix === "deb" || suffix === "rpm" || suffix === "pkg" || suffix === "flatpak")
            return "package_2";
        if (suffix === "msi" || suffix === "msix")
            return "deployed_code";
        if (suffix === "run" || suffix === "bin")
            return "terminal";
        if (["ttf", "otf", "woff", "woff2", "ttc"].indexOf(suffix) >= 0)
            return "font_download";
        if (["json", "toml", "lock"].indexOf(suffix) >= 0)
            return "data_object";
        if (suffix === "xml" || suffix === "xsl" || suffix === "xsd")
            return "code";
        if (suffix === "yml" || suffix === "yaml")
            return "settings";
        if (suffix === "md" || suffix === "markdown" || suffix === "rst" || suffix === "adoc")
            return "markdown";
        if (["html", "htm", "xhtml"].indexOf(suffix) >= 0)
            return "html";
        if (suffix === "css" || suffix === "scss" || suffix === "sass" || suffix === "less")
            return "css";
        if (["js", "mjs", "cjs", "jsx"].indexOf(suffix) >= 0)
            return "javascript";
        if (["ts", "tsx"].indexOf(suffix) >= 0)
            return "code";
        if (["py", "pyw", "ipynb"].indexOf(suffix) >= 0)
            return "code";
        if (["rs", "go", "java", "kt", "kts", "c", "h", "cpp", "hpp", "cc", "cxx", "swift", "zig"].indexOf(suffix) >= 0)
            return "code";
        if (["cs", "fs", "vb", "sln", "csproj"].indexOf(suffix) >= 0)
            return "code";
        if (["php", "rb", "pl", "lua", "r", "jl"].indexOf(suffix) >= 0)
            return "code";
        if (["sh", "bash", "zsh", "fish", "ps1", "bat", "cmd"].indexOf(suffix) >= 0)
            return "terminal";
        if (suffix === "sql" || suffix === "psql")
            return "database";
        if (suffix === "db" || suffix === "sqlite" || suffix === "sqlite3")
            return "database";
        if (suffix === "lnk" || suffix === "url" || suffix === "webloc")
            return "link";
        if (["pem", "crt", "cer", "key", "p12", "pfx", "gpg", "asc"].indexOf(suffix) >= 0)
            return "key";
        if (["blend", "obj", "fbx", "gltf", "glb", "stl", "3ds"].indexOf(suffix) >= 0)
            return "view_in_ar";
        if (["psd", "xcf", "kra", "clip", "ai", "sketch"].indexOf(suffix) >= 0)
            return "palette";
        if (["aup", "aup3", "flp", "als", "mid", "midi"].indexOf(suffix) >= 0)
            return "music_note";
        if (["blend", "nk", "hip", "ma", "mb"].indexOf(suffix) >= 0)
            return "view_in_ar";
        if (["zip", "7z", "7zip", "rar", "tar", "gz", "tgz", "xz", "bz2", "zst", "lz4", "cab"].indexOf(suffix) >= 0)
            return "folder_zip";
        if (suffix === "log")
            return "receipt_long";
        if (suffix === "conf" || suffix === "cfg" || suffix === "ini")
            return "tune";
        if (suffix === "service" || suffix === "timer" || suffix === "socket")
            return "settings_input_component";
        if (name.endsWith(".code-workspace") || mime === "application/vnd.code.workspace")
            return "code";
        if (name === "dockerfile" || name.startsWith("dockerfile.") || suffix === "dockerfile")
            return "deployed_code";
        if (name === "makefile" || name === "gnumakefile" || name === "cmakelists.txt")
            return "build";
        if (mime.startsWith("video/"))
            return "movie";
        if (mime.startsWith("audio/"))
            return "music_note";
        if (mime.startsWith("text/"))
            return "description";
        if (mime.startsWith("image/"))
            return "image";
        if (f.isExecutable)
            return "terminal";
        return "draft";
    }

    function noteInput(kind: string): void {
        root.lastInput = kind;
    }

    function shortcutRename(): void {
        if (root.renameBlocked || root.dialogOpen)
            return;
        root.interacted();
        session.beginRename("");
    }

    function shortcutRefresh(): void {
        if (root.navBlocked || root.dialogOpen)
            return;
        root.interacted();
        session.refresh();
        FileManagerService.refreshMounts();
    }

    function shortcutBack(): void {
        const now = Date.now();
        if (now - root.lastNavAt < 180)
            return;
        root.lastNavAt = now;
        root.noteInput("back");
        if (root.navBlocked || root.dialogOpen)
            return;
        root.interacted();
        session.goBack();
    }

    function shortcutForward(): void {
        const now = Date.now();
        if (now - root.lastNavAt < 180)
            return;
        root.lastNavAt = now;
        root.noteInput("forward");
        if (root.navBlocked || root.dialogOpen)
            return;
        root.interacted();
        session.goForward();
    }

    function shortcutCut(): void {
        root.noteInput("cut");
        if (root.dialogOpen || session.isTrashView || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        session.cutSelection();
    }

    function shortcutCopy(): void {
        root.noteInput("copy");
        if (root.dialogOpen || session.isTrashView || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        session.copySelection();
    }

    function shortcutPaste(): void {
        root.noteInput("paste");
        if (root.dialogOpen || session.isTrashView || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        session.pasteClipboard();
    }

    function shortcutTrash(): void {
        root.noteInput("trash");
        if (root.dialogOpen || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        if (session.isTrashView) {
            if (session.selectedPaths.length)
                root.confirmDeleteOpen = true;
            return;
        }
        session.trashSelection();
    }

    function shortcutUndo(): void {
        root.noteInput("undo");
        if (root.dialogOpen || session.pathEditing || root.renameOpen)
            return;
        if (!session.canUndo())
            return;
        root.interacted();
        session.undoLast();
    }

    function shortcutDeletePermanent(): void {
        root.noteInput("deletePermanent");
        if (root.dialogOpen || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        if (session.selectedPaths.length)
            root.confirmDeleteOpen = true;
    }

    function shortcutToggleHidden(): void {
        root.noteInput("toggleHidden");
        if (root.dialogOpen || session.pathEditing || session.renameTarget.length > 0)
            return;
        root.interacted();
        session.showHidden = !session.showHidden;
        session.refresh();
    }

    function isHiddenEntry(f: var): bool {
        const n = f && f.name ? String(f.name) : "";
        return n.length > 0 && n.charAt(0) === ".";
    }

    MouseArea {
        anchors.fill: parent
        z: 10000
        hoverEnabled: false
        acceptedButtons: Qt.BackButton | Qt.ForwardButton | Qt.ExtraButton1 | Qt.ExtraButton2 | Qt.ExtraButton3 | Qt.ExtraButton4 | Qt.ExtraButton5 | Qt.ExtraButton6
        onPressed: mouse => {
            root.noteInput("mouse:" + mouse.button);
            if (mouse.button === Qt.BackButton || mouse.button === Qt.ExtraButton1 || mouse.button === Qt.ExtraButton3)
                root.shortcutBack();
            else if (mouse.button === Qt.ForwardButton || mouse.button === Qt.ExtraButton2 || mouse.button === Qt.ExtraButton4)
                root.shortcutForward();
            mouse.accepted = true;
        }
    }

    Shortcut {
        sequences: ["Alt+Up"]
        context: Qt.WindowShortcut
        enabled: !root.navBlocked && !root.dialogOpen
        onActivated: session.goUp()
    }
    Shortcut {
        sequences: [StandardKey.Rename, "F2"]
        context: Qt.WindowShortcut
        enabled: !root.renameBlocked && !root.dialogOpen
        onActivated: root.shortcutRename()
    }
    Shortcut {
        sequences: [StandardKey.Refresh, "F5"]
        context: Qt.WindowShortcut
        enabled: !root.navBlocked && !root.dialogOpen
        onActivated: root.shortcutRefresh()
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: session.selectAll()
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: session.copySelection()
    }
    Shortcut {
        sequences: ["Ctrl+X", "Ctrl+x"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: root.shortcutCut()
    }
    Shortcut {
        sequences: [StandardKey.Undo, "Ctrl+Z", "Ctrl+z"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen && session.canUndo()
        onActivated: root.shortcutUndo()
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: session.pasteClipboard()
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: {
            if (session.isTrashView) {
                if (session.selectedPaths.length)
                    root.confirmDeleteOpen = true;
            } else {
                session.trashSelection();
            }
        }
    }
    Shortcut {
        sequences: ["Shift+Del", "Shift+Delete", "Shift+ForwardDelete"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen && session.selectedPaths.length > 0
        onActivated: root.shortcutDeletePermanent()
    }
    Shortcut {
        sequences: ["Ctrl+L"]
        context: Qt.WindowShortcut
        enabled: !root.dialogOpen && !session.renameTarget.length
        onActivated: {
            root.searchOpen = false;
            session.beginPathEdit();
        }
    }
    Shortcut {
        sequences: [StandardKey.Find, "Ctrl+F"]
        context: Qt.WindowShortcut
        enabled: !root.dialogOpen && !session.renameTarget.length
        onActivated: root.openSearch()
    }
    Shortcut {
        sequences: ["Backspace"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: session.goUp()
    }
    Shortcut {
        sequences: ["Alt+Return", "Alt+Enter"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: root.openProperties(session.selectedPaths.length ? "file" : "folder")
    }
    Shortcut {
        sequences: ["Ctrl+H", "Ctrl+h"]
        context: Qt.WindowShortcut
        enabled: !root.inputBlocked && !root.dialogOpen
        onActivated: root.shortcutToggleHidden()
    }

    property string ctxMode: "file" // "file" | "folder" | "bar"

    function displayPath(): string {
        if (session.isTrashView)
            return qsTr("Trash");
        return session.currentPath || "";
    }

    function openSearch(): void {
        if (session.pathEditing)
            session.cancelPathEdit();
        root.searchOpen = true;
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function closeSearch(): void {
        session.searchQuery = "";
        root.searchOpen = false;
        Qt.callLater(() => root.forceActiveFocus());
    }

    function openBarMenu(): void {
        const btn = placesMenuBtn;
        if (!btn)
            return;
        root.ctxMode = "bar";
        fmCtxMenu.height = 80;
        const p = root.mapFromItem(btn, 0, btn.height + 4);
        fmCtxMenu.x = Math.max(8, Math.min(p.x, root.width - fmCtxMenu.width - 8));
        fmCtxMenu.y = Math.max(8, Math.min(p.y, root.height - 80));
        fmCtxMenu.open();
        root.syncCtxMenuGeometry(p);
        Qt.callLater(() => root.syncCtxMenuGeometry(p));
    }

    function openCtxMenu(anchor: var, mx: real, my: real, mode: string): void {
        root.ctxMode = mode || "file";
        fmCtxMenu.height = 80;
        const p = root.mapFromItem(anchor, mx, my);
        fmCtxMenu.x = Math.max(8, Math.min(p.x, root.width - fmCtxMenu.width - 8));
        fmCtxMenu.y = Math.max(8, Math.min(p.y, root.height - 80));
        fmCtxMenu.open();
        root.syncCtxMenuGeometry(p);
        Qt.callLater(() => root.syncCtxMenuGeometry(p));
    }

    function propertiesPaths(mode: string): var {
        if (mode !== "folder" && session.selectedPaths.length)
            return session.selectedPaths.slice();
        if (session.currentPath && session.currentPath.length)
            return [session.currentPath];
        return [];
    }

    function seedProperties(paths: var): void {
        const items = [];
        for (let i = 0; i < paths.length; ++i) {
            const p = paths[i];
            const e = session.entries.find(x => x.path === p);
            if (e) {
                items.push({
                    name: e.name,
                    path: e.path,
                    parent: session.currentPath,
                    isDir: !!e.isDir,
                    isSymlink: !!e.isSymlink,
                    mimeType: e.mimeType || (e.isDir ? "inode/directory" : ""),
                    size: e.size || 0,
                    mtime: e.mtime || 0,
                    originalPath: e.originalPath || "",
                    exists: true
                });
            } else {
                const parts = String(p).split("/").filter(s => s.length);
                items.push({
                    name: p === "trash://" || String(p).startsWith("trash://") ? qsTr("Trash") : (parts.length ? parts[parts.length - 1] : p),
                    path: p,
                    parent: "",
                    isDir: true,
                    mimeType: "inode/directory",
                    size: 0,
                    exists: true
                });
            }
        }
        let total = 0;
        let dirs = 0;
        for (let i = 0; i < items.length; ++i) {
            total += items[i].size || 0;
            if (items[i].isDir)
                dirs += 1;
        }
        root.propertiesInfo = {
            ok: true,
            count: items.length,
            items: items,
            totalSize: total,
            selectedFiles: items.length - dirs,
            selectedDirs: dirs
        };
    }

    function openProperties(mode: string): void {
        if (fmCtxMenu.opened)
            fmCtxMenu.close();
        const paths = root.propertiesPaths(mode || root.ctxMode);
        if (!paths.length)
            return;
        root.seedProperties(paths);
        root.propertiesBusy = true;
        root.propertiesOpen = true;
        FileManagerService.fetchInfo(paths, root);
    }

    function closeProperties(): void {
        root.propertiesOpen = false;
        root.propertiesBusy = false;
    }

    function onInfoReady(data: var): void {
        if (!data || data.ok === false) {
            root.propertiesBusy = false;
            return;
        }
        const prev = root.propertiesInfo || {};
        const prevItems = prev.items || [];
        const items = (data.items || []).map(it => {
            const old = prevItems.find(x => x.path === it.path);
            if (old && old.originalPath && !it.originalPath)
                it.originalPath = old.originalPath;
            return it;
        });
        data.items = items;
        root.propertiesInfo = data;
        root.propertiesBusy = false;
    }

    function formatStamp(secs: var): string {
        const n = Number(secs || 0);
        if (!n)
            return "—";
        return Qt.formatDateTime(new Date(n * 1000), "dd MMM yyyy  HH:mm");
    }

    function propertiesTypeLabel(item: var): string {
        if (!item)
            return "";
        if (item.isDir)
            return item.isSymlink ? qsTr("Folder (link)") : qsTr("Folder");
        if (item.isSymlink)
            return qsTr("Link");
        return item.mimeType || qsTr("File");
    }

    function statusToastTitle(): string {
        const n = session.filteredEntries.length;
        const s = session.selectedPaths.length;
        if (s > 0) {
            const bytes = session.selectedBytes;
            const dirs = session.selectedDirCount;
            const sizePart = bytes > 0 ? FileManagerService.formatBytes(bytes) : "";
            if (dirs > 0 && bytes > 0)
                return qsTr("%1 selected — %2 (+%3 folder(s))").arg(s).arg(sizePart).arg(dirs);
            if (dirs > 0 && bytes === 0)
                return qsTr("%1 selected (%2 folder(s))").arg(s).arg(dirs);
            if (sizePart.length)
                return qsTr("%1 selected — %2").arg(s).arg(sizePart);
            return qsTr("%1 selected").arg(s);
        }
        return qsTr("%1 item(s)").arg(n);
    }

    function pushStatusToast(): void {
        session.upsertToast({
            key: "status",
            lane: "info",
            title: root.statusToastTitle(),
            icon: session.selectedPaths.length ? "check_box" : "folder",
            type: 0,
            timeout: session.selectedPaths.length ? 0 : 2800
        });
    }

    function ctxContentHeight(): real {
        const it = ctxLoader.item;
        if (!it)
            return 80;
        // Never use item.height: a previous tall menu (bar) stretches the loader
        // and Math.max would keep that leftover size.
        return Math.max(it.childrenRect.height, it.implicitHeight || 0, 1);
    }

    function syncCtxMenuGeometry(anchorPoint: var): void {
        if (!fmCtxMenu.opened)
            return;
        const contentH = root.ctxContentHeight();
        fmCtxMenu.height = contentH + fmCtxMenu.padding * 2;
        const p = anchorPoint || Qt.point(fmCtxMenu.x, fmCtxMenu.y);
        fmCtxMenu.x = Math.max(8, Math.min(p.x, root.width - fmCtxMenu.width - 8));
        fmCtxMenu.y = Math.max(8, Math.min(p.y, root.height - fmCtxMenu.height - 8));
    }

    function selectionIsArchive(): bool {
        if (session.selectedPaths.length !== 1)
            return false;
        const entry = session.entries.find(e => e.path === session.selectedPaths[0]);
        return !!(entry && entry.isArchive);
    }

    function selectionHasFolder(entry: var): bool {
        if (entry && entry.isDir)
            return true;
        for (let i = 0; i < session.selectedPaths.length; ++i) {
            const e = session.entries.find(x => x.path === session.selectedPaths[i]);
            if (e && e.isDir)
                return true;
        }
        return false;
    }

    function pinDroppedUrls(urls: var): void {
        const paths = [];
        const src = urls && urls.length ? urls : [];
        for (let i = 0; i < src.length; ++i) {
            const p = FileManagerService.normalizeFsPath(String(src[i] || ""));
            if (!p.length || p.startsWith("trash://"))
                continue;
            const entry = session.entries.find(e => e.path === p);
            if (entry && !entry.isDir)
                continue;
            paths.push(p);
        }
        if (!paths.length && session.selectedPaths.length) {
            for (let i = 0; i < session.selectedPaths.length; ++i) {
                const e = session.entries.find(x => x.path === session.selectedPaths[i]);
                if (e && e.isDir)
                    paths.push(e.path);
            }
        }
        FileManagerService.pinFolders(paths);
    }

    function placeLabel(place: var): string {
        if (!place)
            return "";
        const key = place.key || "";
        if (key === "home")
            return qsTr("Home");
        if (key === "trash")
            return qsTr("Trash");
        // Prefer real folder name (Pictures / Imagens / Documentos / …)
        if (place.label && place.label.length)
            return place.label;
        return key;
    }

    component PinnedPlacesBlock: ColumnLayout {
        id: pins
        spacing: Theme.Appearance.spacing.small
        visible: FileManagerService.pinnedPlaces.length > 0 || root.folderDragActive

        StyledText {
            visible: FileManagerService.pinnedPlaces.length > 0
            text: qsTr("Pinned")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Theme.Appearance.font.size.small
            font.weight: Font.Medium
        }

        Repeater {
            model: FileManagerService.pinnedPlaces

            StyledRect {
                id: pinRow

                required property var modelData
                readonly property bool selected: session.activePlacePath === modelData.path

                Layout.fillWidth: true
                implicitHeight: 36
                radius: Theme.Appearance.rounding.full
                color: selected ? Colours.palette.m3secondaryContainer : "transparent"

                HoverHandler {
                    id: pinHover
                }

                StateLayer {
                    color: pinRow.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    function onClicked(): void {
                        session.navigate(pinRow.modelData.path);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.Appearance.padding.large
                    anchors.rightMargin: Theme.Appearance.padding.small
                    spacing: Theme.Appearance.spacing.normal

                    MaterialIcon {
                        text: pinRow.modelData.icon || "folder"
                        color: pinRow.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        fill: pinRow.selected ? 1 : 0
                        font.pointSize: Theme.Appearance.font.size.normal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: pinRow.modelData.label || ""
                        color: pinRow.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    Item {
                        visible: pinHover.hovered
                        implicitWidth: visible ? 24 : 0
                        implicitHeight: 24
                        z: 2

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: pinRow.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Theme.Appearance.font.size.small
                        }
                        StateLayer {
                            radius: Theme.Appearance.rounding.full
                            function onClicked(): void {
                                FileManagerService.unpinFolder(pinRow.modelData.path);
                            }
                        }
                    }
                }
            }
        }

        Item {
            visible: root.folderDragActive
            Layout.fillWidth: true
            implicitHeight: 48

            Canvas {
                id: dash
                anchors.fill: parent
                property bool hot: pinDrop.containsDrag
                onHotChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = dash.hot ? Colours.palette.m3primary : Colours.palette.m3outline;
                    ctx.strokeStyle = c;
                    ctx.lineWidth = 2;
                    ctx.setLineDash([6, 4]);
                    const r = Theme.Appearance.rounding.normal;
                    const x = 1.5;
                    const y = 1.5;
                    const w = width - 3;
                    const h = height - 3;
                    ctx.beginPath();
                    ctx.moveTo(x + r, y);
                    ctx.lineTo(x + w - r, y);
                    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                    ctx.lineTo(x + w, y + h - r);
                    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                    ctx.lineTo(x + r, y + h);
                    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                    ctx.lineTo(x, y + r);
                    ctx.quadraticCurveTo(x, y, x + r, y);
                    ctx.stroke();
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.Appearance.rounding.normal
                color: pinDrop.containsDrag ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
            }

            StyledText {
                anchors.centerIn: parent
                text: qsTr("Drop folder")
                color: pinDrop.containsDrag ? Colours.palette.m3primary : Colours.palette.m3outline
                font.pointSize: Theme.Appearance.font.size.small
            }

            DropArea {
                id: pinDrop
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: drag => {
                    drag.accept(Qt.CopyAction);
                }
                onDropped: drop => {
                    root.pinDroppedUrls(drop.urls);
                    drop.acceptProposedAction();
                }
            }
        }
    }

    component CtxBtn: Item {
        id: btn

        property string label: ""
        property string iconName: ""
        property bool rowEnabled: true
        property bool destructive: false
        property bool hasSubmenu: false
        property bool checked: false

        signal activated

        width: parent ? parent.width : 232
        height: 36
        opacity: rowEnabled ? 1 : 0.38

        StyledRect {
            anchors.fill: parent
            radius: Theme.Appearance.rounding.small
            color: btnMa.containsMouse && btn.rowEnabled ? Colours.tPalette.m3surfaceContainerHighest : "transparent"
        }

        Item {
            id: btnIconSlot
            anchors.left: parent.left
            anchors.leftMargin: Theme.Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            MaterialIcon {
                anchors.centerIn: parent
                text: btn.iconName
                color: btn.destructive ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font.pointSize: Theme.Appearance.font.size.normal
            }
        }

        StyledText {
            anchors.left: btnIconSlot.right
            anchors.leftMargin: Theme.Appearance.spacing.normal
            anchors.right: btnTrail.left
            anchors.rightMargin: Theme.Appearance.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: btn.destructive ? Colours.palette.m3error : Colours.palette.m3onSurface
            elide: Text.ElideRight
        }

        Item {
            id: btnTrail
            anchors.right: parent.right
            anchors.rightMargin: Theme.Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            width: btn.hasSubmenu || btn.checked ? 18 : 0
            height: 18

            MaterialIcon {
                anchors.centerIn: parent
                visible: btn.hasSubmenu || btn.checked
                text: btn.hasSubmenu ? "chevron_right" : "check"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Theme.Appearance.font.size.normal
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.rowEnabled
            cursorShape: btn.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: {
                if (btn.hasSubmenu) {
                    sortSubCloseTimer.stop();
                    btn.activated();
                    return;
                }
                if (root.inSortSubMenu(btn))
                    sortSubCloseTimer.stop();
                else if (sortSubMenu.opened)
                    sortSubCloseTimer.restart();
            }
            onClicked: {
                if (btn.hasSubmenu) {
                    btn.activated();
                    return;
                }
                sortSubMenu.close();
                fmCtxMenu.close();
                btn.activated();
            }
        }
    }

    component CtxSep: Rectangle {
        width: parent ? parent.width - Theme.Appearance.padding.small * 2 : 200
        height: 1
        x: Theme.Appearance.padding.small
        color: Colours.palette.m3outlineVariant
        opacity: 0.45
    }

    component PropRow: RowLayout {
        id: propRow

        property string label: ""
        property string value: ""
        property bool busy: false

        visible: busy || (value && value.length > 0)
        Layout.fillWidth: true
        spacing: Theme.Appearance.spacing.normal

        StyledText {
            Layout.preferredWidth: 118
            Layout.alignment: Qt.AlignTop
            text: propRow.label
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Theme.Appearance.font.size.small
        }

        StyledText {
            Layout.fillWidth: true
            text: propRow.busy && !(propRow.value && propRow.value.length) ? qsTr("Calculating…") : propRow.value
            color: Colours.palette.m3onSurface
            wrapMode: Text.WrapAnywhere
            font.pointSize: Theme.Appearance.font.size.small
        }
    }

    Component {
        id: barCtxComp

        Column {
            id: barCol
            width: 232
            spacing: 2
            onChildrenRectChanged: {
                if (fmCtxMenu.opened && root.ctxMode === "bar")
                    root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y));
            }

            CtxBtn {
                label: qsTr("New folder")
                iconName: "create_new_folder"
                rowEnabled: !session.isTrashView
                onActivated: session.mkdir()
            }
            CtxBtn {
                label: qsTr("Paste")
                iconName: "content_paste"
                rowEnabled: !session.isTrashView && FileManagerService.clipboardPaths.length > 0
                onActivated: session.pasteClipboard()
            }
            CtxBtn {
                label: qsTr("Open in Terminal")
                iconName: "terminal"
                rowEnabled: !session.isTrashView
                onActivated: session.openTerminal()
            }
            CtxBtn {
                label: qsTr("Parent folder")
                iconName: "arrow_upward"
                onActivated: session.goUp()
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: session.listView ? qsTr("Grid view") : qsTr("List view")
                iconName: session.listView ? "grid_view" : "view_list"
                onActivated: session.listView = !session.listView
            }
            CtxBtn {
                id: sortMenuBtn
                label: qsTr("Sort")
                iconName: "sort"
                hasSubmenu: true
                onActivated: root.openSortSubMenu(sortMenuBtn)
            }
            CtxBtn {
                label: session.showHidden ? qsTr("Hide hidden files") : qsTr("Show hidden files")
                iconName: session.showHidden ? "visibility_off" : "visibility"
                onActivated: root.shortcutToggleHidden()
            }
            CtxBtn {
                label: qsTr("Refresh")
                iconName: "refresh"
                onActivated: {
                    session.refresh();
                    FileManagerService.refreshMounts();
                }
            }
            CtxBtn {
                label: qsTr("Select all")
                iconName: "select_all"
                rowEnabled: session.filteredEntries.length > 0
                onActivated: session.selectAll()
            }
            CtxBtn {
                visible: !root.sidebarExpanded
                height: visible ? 36 : 0
                label: qsTr("Places")
                iconName: "menu"
                onActivated: root.openPlacesFlyout()
            }
        }
    }

    Component {
        id: folderCtxComp

        Column {
            id: folderCol
            width: 232
            spacing: 2
            onChildrenRectChanged: {
                if (fmCtxMenu.opened && root.ctxMode === "folder")
                    root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y));
            }

            CtxBtn {
                label: qsTr("New folder")
                iconName: "create_new_folder"
                rowEnabled: !session.isTrashView
                onActivated: session.mkdir()
            }
            CtxBtn {
                label: qsTr("Paste")
                iconName: "content_paste"
                rowEnabled: !session.isTrashView && FileManagerService.clipboardPaths.length > 0
                onActivated: session.pasteClipboard()
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: qsTr("Select all")
                iconName: "select_all"
                rowEnabled: session.filteredEntries.length > 0
                onActivated: session.selectAll()
            }
            CtxBtn {
                visible: session.isTrashView
                height: visible ? 36 : 0
                label: qsTr("Empty Trash")
                iconName: "delete_sweep"
                destructive: true
                rowEnabled: session.entries.length > 0
                onActivated: root.confirmEmptyTrashOpen = true
            }
            CtxBtn {
                label: qsTr("Open in Terminal")
                iconName: "terminal"
                rowEnabled: !session.isTrashView
                onActivated: session.openTerminal()
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: qsTr("Properties")
                iconName: "info"
                onActivated: root.openProperties("folder")
            }
        }
    }

    Component {
        id: fileCtxComp

        Column {
            id: fileCol
            width: 232
            spacing: 2
            onChildrenRectChanged: {
                if (fmCtxMenu.opened && root.ctxMode === "file")
                    root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y));
            }

            CtxBtn {
                label: session.selectedPaths.length > 1 ? qsTr("Open all") : qsTr("Open")
                iconName: "open_in_new"
                rowEnabled: !session.isTrashView && session.selectedPaths.length > 0
                onActivated: session.openSelection()
            }
            CtxBtn {
                visible: {
                    if (session.isTrashView || !session.selectedPaths.length)
                        return false;
                    for (let i = 0; i < session.selectedPaths.length; ++i) {
                        const e = session.entries.find(x => x.path === session.selectedPaths[i]);
                        if (e && e.isArchive)
                            return true;
                    }
                    return false;
                }
                height: visible ? 36 : 0
                label: {
                    let n = 0;
                    for (let i = 0; i < session.selectedPaths.length; ++i) {
                        const e = session.entries.find(x => x.path === session.selectedPaths[i]);
                        if (e && e.isArchive)
                            n++;
                    }
                    return n > 1 ? qsTr("Extract all here") : qsTr("Extract here");
                }
                iconName: "unarchive"
                rowEnabled: true
                onActivated: {
                    for (let i = 0; i < session.selectedPaths.length; ++i) {
                        const e = session.entries.find(x => x.path === session.selectedPaths[i]);
                        if (e && e.isArchive)
                            FileManagerService.smartExtract(e.path, session.currentPath, session);
                    }
                }
            }
            CtxBtn {
                visible: session.selectedPaths.length > 0 && !session.isTrashView
                height: visible ? 36 : 0
                label: qsTr("Compress to ZIP")
                iconName: "folder_zip"
                rowEnabled: session.selectedPaths.length > 0 && !session.isTrashView
                onActivated: {
                    if (session.selectedPaths.length)
                        FileManagerService.smartCompress(session.selectedPaths.slice(), session.currentPath, "zip", session);
                }
            }
            CtxBtn {
                visible: session.selectedPaths.length > 0 && !session.isTrashView
                height: visible ? 36 : 0
                label: qsTr("Compress to 7z")
                iconName: "archive"
                rowEnabled: session.selectedPaths.length > 0 && !session.isTrashView
                onActivated: {
                    if (session.selectedPaths.length)
                        FileManagerService.smartCompress(session.selectedPaths.slice(), session.currentPath, "7z", session);
                }
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: qsTr("Copy")
                iconName: "content_copy"
                rowEnabled: session.selectedPaths.length > 0 && !session.isTrashView
                onActivated: session.copySelection()
            }
            CtxBtn {
                label: qsTr("Cut")
                iconName: "content_cut"
                rowEnabled: session.selectedPaths.length > 0 && !session.isTrashView
                onActivated: root.shortcutCut()
            }
            CtxBtn {
                label: qsTr("Paste")
                iconName: "content_paste"
                rowEnabled: FileManagerService.clipboardPaths.length > 0 && !session.isTrashView
                onActivated: session.pasteClipboard()
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                visible: root.selectionHasFolder(null) && !session.isTrashView
                height: visible ? 36 : 0
                label: {
                    const path = session.selectedPaths.length === 1 ? session.selectedPaths[0] : "";
                    return path && FileManagerService.isPinned(path) ? qsTr("Unpin from Places") : qsTr("Pin to Places");
                }
                iconName: "bookmark"
                rowEnabled: true
                onActivated: {
                    const dirs = [];
                    for (let i = 0; i < session.selectedPaths.length; ++i) {
                        const e = session.entries.find(x => x.path === session.selectedPaths[i]);
                        if (e && e.isDir)
                            dirs.push(e.path);
                    }
                    if (dirs.length === 1 && FileManagerService.isPinned(dirs[0]))
                        FileManagerService.unpinFolder(dirs[0]);
                    else
                        FileManagerService.pinFolders(dirs);
                }
            }
            CtxBtn {
                label: qsTr("Rename")
                iconName: "drive_file_rename_outline"
                rowEnabled: session.selectedPaths.length === 1 && !session.isTrashView
                onActivated: session.beginRename("")
            }
            CtxBtn {
                label: session.isTrashView ? qsTr("Restore") : qsTr("Move to Trash")
                iconName: session.isTrashView ? "restore_from_trash" : "delete"
                rowEnabled: session.selectedPaths.length > 0
                onActivated: {
                    if (session.isTrashView) {
                        const uris = [];
                        for (let i = 0; i < session.selectedPaths.length; ++i) {
                            const entry = session.entries.find(e => e.path === session.selectedPaths[i]);
                            if (entry && entry.trashUri)
                                uris.push(entry.trashUri);
                        }
                        if (uris.length)
                            FileManagerService.restoreTrash(uris, session);
                    } else {
                        session.trashSelection();
                    }
                }
            }
            CtxBtn {
                label: qsTr("Delete permanently")
                iconName: "delete_forever"
                destructive: true
                rowEnabled: session.selectedPaths.length > 0
                onActivated: root.confirmDeleteOpen = true
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: qsTr("Open in Terminal")
                iconName: "terminal"
                rowEnabled: !session.isTrashView
                onActivated: session.openTerminal()
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: qsTr("Properties")
                iconName: "info"
                rowEnabled: session.selectedPaths.length > 0
                onActivated: root.openProperties("file")
            }
        }
    }

    QC.Popup {
        id: fmCtxMenu

        parent: root
        padding: Theme.Appearance.padding.small
        width: 232 + Theme.Appearance.padding.small * 2
        modal: false
        dim: false
        focus: true
        clip: true
        closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside
        transformOrigin: Item.TopLeft

        background: StyledRect {
            radius: Theme.Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
        }

        onOpened: root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y))
        onClosed: sortSubMenu.close()

        contentItem: Loader {
            id: ctxLoader
            width: 232
            sourceComponent: root.ctxMode === "bar" ? barCtxComp : (root.ctxMode === "folder" ? folderCtxComp : fileCtxComp)
            onLoaded: {
                root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y));
                Qt.callLater(() => root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y)));
            }
            onItemChanged: root.syncCtxMenuGeometry(Qt.point(fmCtxMenu.x, fmCtxMenu.y))
        }
    }

    QC.Popup {
        id: sortSubMenu

        parent: root
        padding: Theme.Appearance.padding.small
        width: 216 + Theme.Appearance.padding.small * 2
        modal: false
        dim: false
        focus: false
        clip: true
        closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside
        transformOrigin: Item.TopLeft

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    sortSubCloseTimer.stop();
                else
                    sortSubCloseTimer.restart();
            }
        }

        background: StyledRect {
            radius: Theme.Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
        }

        Column {
            width: 216
            spacing: 2

            CtxBtn {
                label: qsTr("Name")
                iconName: "sort_by_alpha"
                checked: session.sortBy === "name"
                onActivated: session.setSortBy("name")
            }
            CtxBtn {
                label: qsTr("Size")
                iconName: "data_usage"
                checked: session.sortBy === "size"
                onActivated: session.setSortBy("size")
            }
            CtxBtn {
                label: qsTr("Modified")
                iconName: "schedule"
                checked: session.sortBy === "mtime"
                onActivated: session.setSortBy("mtime")
            }
            CtxBtn {
                label: qsTr("Type")
                iconName: "category"
                checked: session.sortBy === "type"
                onActivated: session.setSortBy("type")
            }
            Item {
                width: 1
                height: 4
            }
            CtxSep {}
            Item {
                width: 1
                height: 4
            }
            CtxBtn {
                label: session.sortAsc ? qsTr("Descending") : qsTr("Ascending")
                iconName: session.sortAsc ? "arrow_downward" : "arrow_upward"
                onActivated: session.sortAsc = !session.sortAsc
            }
        }
    }

    Timer {
        id: sortSubCloseTimer
        interval: 180
        repeat: false
        onTriggered: sortSubMenu.close()
    }

    function inSortSubMenu(item: var): bool {
        let p = item;
        while (p) {
            if (p === sortSubMenu)
                return true;
            p = p.parent;
        }
        return false;
    }

    function openSortSubMenu(btn: var): void {
        if (!btn || !fmCtxMenu.opened)
            return;
        const gap = -2;
        const w = sortSubMenu.width;
        const h = Math.max(sortSubMenu.implicitHeight, 220);
        let p = root.mapFromItem(btn, btn.width + gap, 0);
        if (p.x + w > root.width - 8)
            p = root.mapFromItem(btn, -w - gap, 0);
        sortSubMenu.x = Math.max(8, Math.min(p.x, root.width - w - 8));
        sortSubMenu.y = Math.max(8, Math.min(p.y, root.height - h - 8));
        if (!sortSubMenu.opened)
            sortSubMenu.open();
    }

    function openPlacesFlyout(): void {
        const btn = placesMenuBtn;
        if (!btn || root.sidebarExpanded)
            return;
        placesFlyout.width = 250;
        placesFlyout.open();
        root.syncPlacesFlyoutGeometry();
        Qt.callLater(root.syncPlacesFlyoutGeometry);
    }

    function syncPlacesFlyoutGeometry(): void {
        const btn = placesMenuBtn;
        if (!btn || !placesFlyout.opened)
            return;
        const pad = Theme.Appearance.padding.normal * 2;
        const contentH = Math.max(placesFlyoutCol.implicitHeight, placesFlyoutCol.childrenRect.height);
        placesFlyout.height = Math.min(root.height - 48, Math.max(contentH + pad, 160));
        const p = root.mapFromItem(btn, 0, btn.height + 2);
        placesFlyout.x = Math.max(8, Math.min(p.x, root.width - placesFlyout.width - 8));
        placesFlyout.y = Math.max(8, Math.min(p.y, root.height - placesFlyout.height - 8));
    }

    function schedulePlacesFlyoutClose(): void {
        if (placesFlyoutHover.hovered || placesMenuBtnHover.hovered)
            placesCloseTimer.stop();
        else
            placesCloseTimer.restart();
    }

    function navigateFromFlyout(path: string): void {
        placesFlyout.close();
        session.navigate(path);
    }

    onWidthChanged: {
        if (root.sidebarExpanded && placesFlyout.opened)
            placesFlyout.close();
    }

    Timer {
        id: placesCloseTimer
        interval: 220
        onTriggered: {
            if (!placesFlyoutHover.hovered && !placesMenuBtnHover.hovered)
                placesFlyout.close();
        }
    }

    // Compact Places/Devices flyout (same look as the sidebar)
    QC.Popup {
        id: placesFlyout

        parent: root
        width: 250
        padding: Theme.Appearance.padding.normal
        modal: false
        dim: false
        focus: true
        closePolicy: QC.Popup.CloseOnEscape

        background: StyledRect {
            radius: Theme.Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
        }

        HoverHandler {
            id: placesFlyoutHover
            onHoveredChanged: root.schedulePlacesFlyoutClose()
        }

        onOpened: root.syncPlacesFlyoutGeometry()

        contentItem: Flickable {
            id: placesFlyoutFlick
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: placesFlyoutCol.implicitHeight
            interactive: contentHeight > height

            ColumnLayout {
                id: placesFlyoutCol
                width: placesFlyoutFlick.width > 0 ? placesFlyoutFlick.width : 250 - Theme.Appearance.padding.normal * 2
                spacing: Theme.Appearance.spacing.small

                onImplicitHeightChanged: {
                    if (placesFlyout.opened)
                        root.syncPlacesFlyoutGeometry();
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Appearance.spacing.small

                    MaterialIcon {
                        text: "folder_open"
                        fill: 1
                        color: Colours.palette.m3primary
                        font.pointSize: Theme.Appearance.font.size.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Files")
                        font.pointSize: Theme.Appearance.font.size.larger
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurface
                    }
                }

                StyledText {
                    text: qsTr("Places")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.Medium
                    Layout.topMargin: Theme.Appearance.spacing.small
                }

                Repeater {
                    model: FileManagerService.places

                    StyledRect {
                        id: flyPlace

                        required property var modelData
                        readonly property bool selected: session.activePlacePath === modelData.path

                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: selected ? Colours.palette.m3secondaryContainer : "transparent"

                        StateLayer {
                            color: flyPlace.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.navigateFromFlyout(flyPlace.modelData.path);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.Appearance.padding.large
                            anchors.rightMargin: Theme.Appearance.padding.large
                            spacing: Theme.Appearance.spacing.normal

                            MaterialIcon {
                                text: flyPlace.modelData.icon
                                color: flyPlace.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                fill: flyPlace.selected ? 1 : 0
                                font.pointSize: Theme.Appearance.font.size.normal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.placeLabel(flyPlace.modelData)
                                color: flyPlace.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                PinnedPlacesBlock {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.Appearance.spacing.small
                }

                StyledText {
                    text: qsTr("Devices")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.Medium
                    Layout.topMargin: Theme.Appearance.spacing.normal
                }

                Repeater {
                    model: FileManagerService.mounts

                    StyledRect {
                        id: flyDevice

                        required property var modelData
                        readonly property bool isMounted: !!modelData.mounted

                        Layout.fillWidth: true
                        implicitHeight: flyDeviceCol.implicitHeight + Theme.Appearance.padding.normal * 2
                        radius: Theme.Appearance.rounding.normal
                        color: "transparent"
                        opacity: flyDevice.isMounted ? 1 : 0.85

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                if (flyDevice.isMounted && flyDevice.modelData.mount)
                                    root.navigateFromFlyout(flyDevice.modelData.mount);
                                else if (flyDevice.modelData.devicePath) {
                                    placesFlyout.close();
                                    session.mountAndOpen(flyDevice.modelData.devicePath);
                                }
                            }
                        }

                        ColumnLayout {
                            id: flyDeviceCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.Appearance.padding.normal
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.Appearance.spacing.small

                                MaterialIcon {
                                    text: flyDevice.modelData.removable ? "usb" : (flyDevice.modelData.mount === "/" ? "hard_drive" : "storage")
                                    color: Colours.palette.m3onSurface
                                    font.pointSize: Theme.Appearance.font.size.normal
                                    fill: flyDevice.isMounted ? 1 : 0
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: flyDevice.modelData.name
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                    font.weight: Font.Medium
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                visible: flyDevice.isMounted

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Colours.palette.m3surfaceContainerHighest
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.min(1, Math.max(0, flyDevice.modelData.perc || 0))
                                    radius: height / 2
                                    color: {
                                        const p = flyDevice.modelData.perc || 0;
                                        if (p >= 0.9)
                                            return Colours.palette.m3error;
                                        if (p >= 0.75)
                                            return Colours.palette.m3tertiary;
                                        return Colours.palette.m3primary;
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: flyDevice.isMounted
                                    ? qsTr("%1 free of %2").arg(FileManagerService.formatBytes(flyDevice.modelData.free)).arg(FileManagerService.formatBytes(flyDevice.modelData.total))
                                    : qsTr("Not mounted — click to open")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Theme.Appearance.font.size.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                StyledText {
                    visible: FileManagerService.mounts.length === 0
                    text: qsTr("No mounts found")
                    color: Colours.palette.m3outline
                    font.pointSize: Theme.Appearance.font.size.small
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Shift)
            root.shiftHeld = true;
        else if (event.key === Qt.Key_Control)
            root.ctrlHeld = true;
        root.noteInput("key:" + event.key + ":mod" + event.modifiers);
        if (root.confirmDeleteOpen) {
            if (event.key === Qt.Key_Escape) {
                root.confirmDeleteOpen = false;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.confirmDeleteOpen = false;
                session.deletePermanentSelection();
                event.accepted = true;
                return;
            }
        }
        if (root.confirmEmptyTrashOpen) {
            if (event.key === Qt.Key_Escape) {
                root.confirmEmptyTrashOpen = false;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.confirmEmptyTrashOpen = false;
                session.emptyTrash();
                event.accepted = true;
                return;
            }
        }
        if (root.propertiesOpen) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.closeProperties();
                event.accepted = true;
                return;
            }
        }
        if (root.renameOpen) {
            if (event.key === Qt.Key_Escape) {
                session.cancelRename();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                session.commitRename(renameField.text);
                event.accepted = true;
                return;
            }
            return;
        }
        if (session.pathEditing) {
            if (event.key === Qt.Key_Escape) {
                session.cancelPathEdit();
                event.accepted = true;
                return;
            }
        }
        if (event.key === Qt.Key_Escape) {
            if (root.searchOpen) {
                root.closeSearch();
                event.accepted = true;
                return;
            }
            if (session.appToastVisible) {
                session.dismissAppToast();
                event.accepted = true;
                return;
            }
            if (session.selectedPaths.length) {
                session.clearSelection();
                event.accepted = true;
                return;
            }
            root.requestClose();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace && !(event.modifiers & Qt.ControlModifier)) {
            if (session.renameTarget.length)
                return;
            session.goUp();
            event.accepted = true;
        } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            session.selectAll();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            root.shortcutRename();
            event.accepted = true;
        } else if (event.key === Qt.Key_F5) {
            root.shortcutRefresh();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
            root.openProperties(session.selectedPaths.length ? "file" : "folder");
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) {
            root.shortcutBack();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.AltModifier)) {
            root.shortcutForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            session.copySelection();
            event.accepted = true;
        } else if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier)) {
            root.shortcutCut();
            event.accepted = true;
        } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.ShiftModifier)) {
            root.shortcutUndo();
            event.accepted = true;
        } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            session.pasteClipboard();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_ForwardDelete) {
            if (event.modifiers & Qt.ShiftModifier)
                root.shortcutDeletePermanent();
            else
                root.shortcutTrash();
            event.accepted = true;
        } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
            session.beginPathEdit();
            event.accepted = true;
        } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
            root.shortcutToggleHidden();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && session.selectedPaths.length > 0) {
            session.openSelection();
            event.accepted = true;
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Shift)
            root.shiftHeld = false;
        else if (event.key === Qt.Key_Control)
            root.ctrlHeld = false;
    }

    onIsWindowActiveChanged: {
        if (!root.isWindowActive) {
            root.shiftHeld = false;
            root.ctrlHeld = false;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        StyledRect {
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarExpanded ? 250 : 0
            Layout.maximumWidth: root.sidebarExpanded ? 250 : 0
            visible: root.sidebarExpanded
            clip: true
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Appearance.padding.normal
                spacing: Theme.Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Appearance.spacing.small

                    MaterialIcon {
                        text: "folder_open"
                        fill: 1
                        color: Colours.palette.m3primary
                        font.pointSize: Theme.Appearance.font.size.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Files")
                        font.pointSize: Theme.Appearance.font.size.larger
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurface
                    }
                }

                StyledText {
                    text: qsTr("Places")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.Medium
                    Layout.topMargin: Theme.Appearance.spacing.small
                }

                Repeater {
                    model: FileManagerService.places

                    StyledRect {
                        id: place

                        required property var modelData
                        readonly property bool selected: session.activePlacePath === modelData.path

                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: selected ? Colours.palette.m3secondaryContainer : "transparent"

                        StateLayer {
                            color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            function onClicked(): void {
                                session.navigate(place.modelData.path);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.Appearance.padding.large
                            anchors.rightMargin: Theme.Appearance.padding.large
                            spacing: Theme.Appearance.spacing.normal

                            MaterialIcon {
                                text: place.modelData.icon
                                color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                fill: place.selected ? 1 : 0
                                font.pointSize: Theme.Appearance.font.size.normal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.placeLabel(place.modelData)
                                color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                PinnedPlacesBlock {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.Appearance.spacing.small
                }

                StyledText {
                    text: qsTr("Devices")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.Medium
                    Layout.topMargin: Theme.Appearance.spacing.normal
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: devicesCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: devicesCol
                        width: parent.width
                        spacing: Theme.Appearance.spacing.small

                        Repeater {
                            model: FileManagerService.mounts

                            StyledRect {
                                id: device

                                required property var modelData
                                readonly property bool isMounted: !!modelData.mounted

                                Layout.fillWidth: true
                                implicitHeight: deviceCol.implicitHeight + Theme.Appearance.padding.normal * 2
                                radius: Theme.Appearance.rounding.normal
                                color: "transparent"
                                opacity: device.isMounted ? 1 : 0.85

                                StateLayer {
                                    color: Colours.palette.m3onSurface
                                    function onClicked(): void {
                                        if (device.isMounted && device.modelData.mount)
                                            session.navigate(device.modelData.mount);
                                        else if (device.modelData.devicePath)
                                            session.mountAndOpen(device.modelData.devicePath);
                                    }
                                }

                                ColumnLayout {
                                    id: deviceCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Theme.Appearance.padding.normal
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.Appearance.spacing.small

                                        MaterialIcon {
                                            text: device.modelData.removable ? "usb" : (device.modelData.mount === "/" ? "hard_drive" : "storage")
                                            color: Colours.palette.m3onSurface
                                            font.pointSize: Theme.Appearance.font.size.normal
                                            fill: device.isMounted ? 1 : 0
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: device.modelData.name
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                            font.weight: Font.Medium
                                        }

                                        Item {
                                            visible: !!(device.modelData.ejectable && device.isMounted)
                                            implicitWidth: visible ? 28 : 0
                                            implicitHeight: 28
                                            z: 2

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: "eject"
                                                color: Colours.palette.m3onSurfaceVariant
                                                font.pointSize: Theme.Appearance.font.size.small
                                            }

                                            StateLayer {
                                                radius: Theme.Appearance.rounding.full
                                                color: Colours.palette.m3onSurface
                                                function onClicked(): void {
                                                    session.requestEject(device.modelData.mount);
                                                }

                                                QC.ToolTip.visible: containsMouse
                                                QC.ToolTip.delay: 400
                                                QC.ToolTip.text: qsTr("Eject")
                                            }
                                        }
                                    }

                                    // Usage progress bar (mounted only)
                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 6
                                        visible: device.isMounted

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: Colours.palette.m3surfaceContainerHighest
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * Math.min(1, Math.max(0, device.modelData.perc || 0))
                                            radius: height / 2
                                            color: {
                                                const p = device.modelData.perc || 0;
                                                if (p >= 0.9)
                                                    return Colours.palette.m3error;
                                                if (p >= 0.75)
                                                    return Colours.palette.m3tertiary;
                                                return Colours.palette.m3primary;
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: device.isMounted
                                            ? qsTr("%1 free of %2").arg(FileManagerService.formatBytes(device.modelData.free)).arg(FileManagerService.formatBytes(device.modelData.total))
                                            : qsTr("Not mounted — click to open")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Theme.Appearance.font.size.small
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: FileManagerService.mounts.length === 0
                            text: qsTr("No mounts found")
                            color: Colours.palette.m3outline
                            font.pointSize: Theme.Appearance.font.size.small
                        }
                    }
                }
            }
        }

        // Main pane
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Toolbar: ⋮  path  🔍
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 36 + Theme.Appearance.padding.normal * 2
                color: Colours.tPalette.m3surfaceContainer

                StyledRect {
                    id: toolbarRow
                    anchors.fill: parent
                    anchors.margins: Theme.Appearance.padding.normal
                    radius: Theme.Appearance.rounding.small
                    color: Colours.tPalette.m3surfaceContainerHigh
                    border.width: session.pathEditing || root.searchOpen ? 1 : 0
                    border.color: Colours.palette.m3primary
                    clip: true

                    Behavior on border.color {
                        CAnim {}
                    }
                    Behavior on color {
                        CAnim {}
                    }

                    Item {
                        id: placesMenuBtn
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36

                        HoverHandler {
                            id: placesMenuBtnHover
                            onHoveredChanged: root.schedulePlacesFlyoutClose()
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "more_vert"
                            color: Colours.palette.m3onSurface
                        }
                        StateLayer {
                            radius: Theme.Appearance.rounding.small
                            function onClicked(): void {
                                if (placesFlyout.opened)
                                    placesFlyout.close();
                                root.openBarMenu();
                            }
                        }
                    }

                    Item {
                        anchors.left: placesMenuBtn.right
                        anchors.right: emptyTrashBtn.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        MouseArea {
                            anchors.fill: parent
                            enabled: !session.pathEditing && !root.searchOpen
                            cursorShape: Qt.IBeamCursor
                            onClicked: session.beginPathEdit()
                        }

                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 8
                            visible: !session.pathEditing && !root.searchOpen
                            text: root.displayPath()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                            font.pointSize: Theme.Appearance.font.size.normal
                        }

                        TextInput {
                            id: pathField
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 8
                            visible: session.pathEditing && !root.searchOpen
                            text: session.pathEditText
                            color: Colours.palette.m3onSurface
                            selectedTextColor: Colours.palette.m3onPrimary
                            selectionColor: Colours.palette.m3primary
                            font.pointSize: Theme.Appearance.font.size.normal
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextEdited: session.pathEditText = text
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    session.commitPathEdit();
                                    root.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    session.cancelPathEdit();
                                    root.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                            onVisibleChanged: {
                                if (visible) {
                                    forceActiveFocus();
                                    selectAll();
                                }
                            }
                        }

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 8
                            visible: root.searchOpen
                            color: Colours.palette.m3onSurface
                            selectedTextColor: Colours.palette.m3onPrimary
                            selectionColor: Colours.palette.m3primary
                            font.pointSize: Theme.Appearance.font.size.normal
                            text: session.searchQuery
                            onTextChanged: session.searchQuery = text
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onEscapePressed: root.closeSearch()
                            onActiveFocusChanged: {
                                if (!activeFocus && !session.searchQuery.length)
                                    root.searchOpen = false;
                            }

                            Text {
                                anchors.fill: parent
                                text: qsTr("Search…")
                                color: Colours.palette.m3outline
                                visible: !parent.text.length && !parent.activeFocus
                                font: parent.font
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item {
                        id: emptyTrashBtn
                        anchors.right: searchBtn.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: session.isTrashView
                        width: visible ? 36 : 0
                        height: 36
                        opacity: session.entries.length > 0 ? 1 : 0.38

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete_sweep"
                            color: session.entries.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        }
                        StateLayer {
                            enabled: session.entries.length > 0
                            radius: Theme.Appearance.rounding.small
                            color: Colours.palette.m3error
                            function onClicked(): void {
                                root.confirmEmptyTrashOpen = true;
                            }

                            QC.ToolTip.visible: containsMouse
                            QC.ToolTip.delay: 400
                            QC.ToolTip.text: qsTr("Empty Trash")
                        }
                    }

                    Item {
                        id: searchBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "search"
                            color: root.searchOpen ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        }
                        StateLayer {
                            radius: Theme.Appearance.rounding.small
                            function onClicked(): void {
                                if (root.searchOpen)
                                    root.closeSearch();
                                else
                                    root.openSearch();
                            }
                        }
                    }
                }
            }

            // File area
            StyledRect {
                id: fileArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colours.palette.m3surface

                DropArea {
                    anchors.fill: parent
                    enabled: !session.isTrashView
                    keys: ["text/uri-list"]
                    onEntered: drag => {
                        // Prefer move internally; Ctrl held → copy (platform sets proposedAction)
                        if (drag.supportedActions & Qt.MoveAction)
                            drag.accept(Qt.MoveAction);
                        else if (drag.supportedActions & Qt.CopyAction)
                            drag.accept(Qt.CopyAction);
                    }
                    onDropped: drop => {
                        if (drop.hasUrls) {
                            const wantCopy = drop.action === Qt.CopyAction;
                            session.importDroppedUrls(drop.urls, wantCopy, session.currentPath);
                        }
                        drop.acceptProposedAction();
                    }
                }

                Loader {
                    anchors.centerIn: parent
                    active: session.filteredEntries.length === 0
                    sourceComponent: ColumnLayout {
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: session.busy ? "progress_activity" : "folder_off"
                            color: Colours.palette.m3outline
                            font.pointSize: Theme.Appearance.font.size.extraLarge * 2
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: session.busy ? qsTr("Loading…") : qsTr("This folder is empty")
                            color: Colours.palette.m3outline
                            font.pointSize: Theme.Appearance.font.size.large
                        }
                    }
                }

                // List view
                ListView {
                    id: fileList
                    anchors.fill: parent
                    anchors.leftMargin: Theme.Appearance.padding.normal
                    anchors.rightMargin: Theme.Appearance.padding.normal
                    anchors.topMargin: Theme.Appearance.padding.small
                    anchors.bottomMargin: Theme.Appearance.padding.small
                    clip: true
                    visible: session.listView
                    model: session.filteredEntries
                    spacing: 2
                    focus: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    Keys.forwardTo: [root]

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: fileList
                    }

                    delegate: StyledRect {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool selected: session.isSelected(modelData.path)
                        readonly property bool markedCut: session.isMarkedCut(modelData.path)
                        readonly property bool hidden: root.isHiddenEntry(modelData)
                        readonly property string glyph: root.fileGlyph(modelData)

                        width: fileList.width
                        implicitHeight: 44
                        radius: Theme.Appearance.rounding.small
                        opacity: row.markedCut ? 0.45 : (row.hidden ? 0.55 : 1)
                        property bool dropTarget: false
                        color: dropTarget ? root.fmDropBg : (selected ? root.fmSelectBg : (rowHover.containsMouse ? root.fmHoverBg : "transparent"))
                        border.width: selected || dropTarget ? 1 : 0
                        border.color: dropTarget ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3primary, selected ? 0.35 : 0)

                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on border.color {
                            CAnim {}
                        }
                        Behavior on opacity {
                            Anim {
                                duration: Theme.Appearance.anim.durations.small
                            }
                        }

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                        Drag.proposedAction: Qt.MoveAction
                        property string dragUris: ""
                        Drag.mimeData: {
                            "text/uri-list": row.dragUris
                        }
                        Drag.keys: ["text/uri-list"]
                        Drag.onActiveChanged: {
                            if (!row.Drag.active && root.pendingDragItem === row)
                                root.endFileDrag(row);
                        }

                        DropArea {
                            anchors.fill: parent
                            enabled: !!(row.modelData && row.modelData.isDir) && !session.isTrashView && !(root.fileDragActive && session.isSelected(row.modelData.path))
                            keys: ["text/uri-list"]
                            onEntered: drag => {
                                if (drag.supportedActions & Qt.MoveAction)
                                    drag.accept(Qt.MoveAction);
                                else if (drag.supportedActions & Qt.CopyAction)
                                    drag.accept(Qt.CopyAction);
                                row.dropTarget = true;
                            }
                            onExited: row.dropTarget = false
                            onDropped: drop => {
                                row.dropTarget = false;
                                if (drop.hasUrls)
                                    session.importDroppedUrls(drop.urls, drop.action === Qt.CopyAction, row.modelData.path);
                                drop.acceptProposedAction();
                            }
                        }

                        DragHandler {
                            id: rowDrag
                            enabled: false
                            target: null
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.Appearance.padding.normal
                            anchors.rightMargin: Theme.Appearance.padding.normal
                            spacing: Theme.Appearance.spacing.normal

                            Loader {
                                visible: active
                                Layout.preferredWidth: active ? 28 : 0
                                Layout.preferredHeight: active ? 28 : 0
                                active: !!(row.modelData && row.modelData.canThumbnail)
                                sourceComponent: FmThumb {
                                    entry: row.modelData
                                    implicitSize: 28
                                }
                            }

                            MaterialIcon {
                                visible: !(row.modelData && row.modelData.canThumbnail)
                                text: row.glyph
                                color: {
                                    if (row.dropTarget || row.selected)
                                        return Colours.palette.m3primary;
                                    if (row.modelData && row.modelData.isDir)
                                        return Colours.palette.m3primary;
                                    return Colours.palette.m3onSurfaceVariant;
                                }
                                font.pointSize: Theme.Appearance.font.size.large
                                fill: row.modelData && row.modelData.isDir ? 1 : 0

                                Behavior on color {
                                    CAnim {}
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: row.selected || row.dropTarget ? Colours.palette.m3primary : (row.hidden ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)
                                elide: Text.ElideMiddle
                                font.weight: row.selected ? Font.Medium : Font.Normal
                                font.italic: row.hidden

                                Behavior on color {
                                    CAnim {}
                                }
                            }

                            StyledText {
                                visible: !row.modelData.isDir
                                text: FileManagerService.formatBytes(row.modelData.size || 0)
                                color: row.selected ? Qt.alpha(Colours.palette.m3primary, 0.8) : Colours.palette.m3onSurfaceVariant
                                font.pointSize: Theme.Appearance.font.size.small
                                Layout.preferredWidth: 80
                                horizontalAlignment: Text.AlignRight

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }
                }

                // Grid view
                GridView {
                    id: fileGrid
                    anchors.fill: parent
                    anchors.margins: Theme.Appearance.padding.normal
                    clip: true
                    visible: !session.listView
                    model: session.filteredEntries
                    cellWidth: 120
                    cellHeight: 130
                    focus: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    Keys.forwardTo: [root]

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: fileGrid
                    }

                    delegate: Item {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property bool selected: session.isSelected(modelData.path)
                        readonly property bool markedCut: session.isMarkedCut(modelData.path)
                        readonly property bool hidden: root.isHiddenEntry(modelData)
                        readonly property bool canThumb: !!(modelData && modelData.canThumbnail)
                        readonly property string glyph: root.fileGlyph(modelData)

                        width: fileGrid.cellWidth
                        height: fileGrid.cellHeight
                        opacity: tile.markedCut ? 0.45 : (tile.hidden ? 0.55 : 1)
                        property bool dropTarget: false
                        scale: tileHover.containsMouse && !tile.selected ? 1.03 : 1

                        Behavior on opacity {
                            Anim {
                                duration: Theme.Appearance.anim.durations.small
                            }
                        }
                        Behavior on scale {
                            Anim {
                                duration: Theme.Appearance.anim.durations.small
                                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveFastSpatial
                            }
                        }

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                        Drag.proposedAction: Qt.MoveAction
                        property string dragUris: ""
                        Drag.mimeData: {
                            "text/uri-list": tile.dragUris
                        }
                        Drag.keys: ["text/uri-list"]
                        Drag.onActiveChanged: {
                            if (!tile.Drag.active && root.pendingDragItem === tile)
                                root.endFileDrag(tile);
                        }

                        DropArea {
                            anchors.fill: parent
                            enabled: !!(tile.modelData && tile.modelData.isDir) && !session.isTrashView && !(root.fileDragActive && session.isSelected(tile.modelData.path))
                            keys: ["text/uri-list"]
                            onEntered: drag => {
                                if (drag.supportedActions & Qt.MoveAction)
                                    drag.accept(Qt.MoveAction);
                                else if (drag.supportedActions & Qt.CopyAction)
                                    drag.accept(Qt.CopyAction);
                                tile.dropTarget = true;
                            }
                            onExited: tile.dropTarget = false
                            onDropped: drop => {
                                tile.dropTarget = false;
                                if (drop.hasUrls)
                                    session.importDroppedUrls(drop.urls, drop.action === Qt.CopyAction, tile.modelData.path);
                                drop.acceptProposedAction();
                            }
                        }

                        DragHandler {
                            id: tileDrag
                            enabled: false
                            target: null
                        }

                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Theme.Appearance.padding.small
                            width: parent.width - Theme.Appearance.padding.small * 2
                            spacing: Theme.Appearance.spacing.small

                            StyledRect {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: 72
                                implicitHeight: 72
                                radius: Theme.Appearance.rounding.normal
                                color: tile.dropTarget ? root.fmDropBg : (tile.selected ? root.fmSelectBg : (tileHover.containsMouse ? root.fmHoverBg : "transparent"))
                                border.width: tile.selected || tile.dropTarget ? 1 : 0
                                border.color: tile.dropTarget ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3primary, tile.selected ? 0.4 : 0)

                                Behavior on color {
                                    CAnim {}
                                }
                                Behavior on border.color {
                                    CAnim {}
                                }

                                Loader {
                                    anchors.centerIn: parent
                                    width: 56
                                    height: 56
                                    active: tile.canThumb
                                    visible: active
                                    sourceComponent: FmThumb {
                                        entry: tile.modelData
                                        implicitSize: 56
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: !tile.canThumb
                                    text: tile.glyph
                                    color: {
                                        if (tile.selected || tile.dropTarget)
                                            return Colours.palette.m3primary;
                                        if (tile.modelData && tile.modelData.isDir)
                                            return Colours.palette.m3primary;
                                        return Colours.palette.m3onSurfaceVariant;
                                    }
                                    font.pointSize: Theme.Appearance.font.size.extraLarge
                                    fill: tile.modelData && tile.modelData.isDir ? 1 : 0

                                    Behavior on color {
                                        CAnim {}
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                text: tile.modelData.name
                                color: tile.selected ? Colours.palette.m3primary : (tile.hidden ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                font.pointSize: Theme.Appearance.font.size.small
                                font.weight: tile.selected ? Font.Medium : Font.Normal
                                font.italic: tile.hidden

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }
                }

                // Empty-space marquee + file drag (overlay must own both — DragHandler under MouseArea never runs)
                MouseArea {
                    id: emptyMarquee
                    anchors.fill: parent
                    z: 40
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false
                    preventStealing: root.marqueeActive || root.marqueePending || root.fileDragActive
                    enabled: !root.dialogOpen && !session.pathEditing
                    property real pressX: 0
                    property real pressY: 0
                    property int pressMods: 0
                    property string pressHit: ""
                    property var pressItem: null

                    function itemAt(areaX: real, areaY: real): var {
                        const view = session.listView ? fileList : fileGrid;
                        if (!view || !view.visible || !view.contentItem)
                            return null;
                        const p = view.contentItem.mapFromItem(fileArea, areaX, areaY);
                        return view.itemAt(p.x, p.y);
                    }

                    onPressed: mouse => {
                        const hit = root.hitFileAt(mouse.x, mouse.y);
                        pressX = mouse.x;
                        pressY = mouse.y;
                        pressMods = mouse.modifiers;
                        pressHit = hit;
                        pressItem = hit.length ? emptyMarquee.itemAt(mouse.x, mouse.y) : null;
                        root.claimFocus();

                        if (hit.length) {
                            if (root.isShiftDown(mouse.modifiers) || root.isCtrlDown(mouse.modifiers)) {
                                root.clickSelectPath(hit, mouse.modifiers);
                                pressHit = "";
                                pressItem = null;
                            }
                            return;
                        }

                        pressHit = "";
                        pressItem = null;
                        root.marqueePending = true;
                        root.marqueeActive = false;
                        root.marqueeMoved = false;
                        if (!root.isCtrlDown(mouse.modifiers) && !root.isShiftDown(mouse.modifiers))
                            session.clearSelection();
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;

                        if (pressHit.length && pressItem && pressItem.modelData && !root.fileDragActive && !session.isTrashView) {
                            const dx = mouse.x - pressX;
                            const dy = mouse.y - pressY;
                            if ((dx * dx + dy * dy) >= root.marqueeThreshold * root.marqueeThreshold) {
                                root.beginFileDrag(pressItem, pressItem.modelData, null);
                                pressHit = "";
                                pressItem = null;
                            }
                            return;
                        }

                        if (root.fileDragActive)
                            return;

                        if (root.marqueeActive) {
                            root.updateMarquee(mouse.x, mouse.y);
                            return;
                        }
                        if (!root.marqueePending)
                            return;
                        const dx = mouse.x - pressX;
                        const dy = mouse.y - pressY;
                        if ((dx * dx + dy * dy) < root.marqueeThreshold * root.marqueeThreshold)
                            return;
                        root.beginMarquee(pressX, pressY, root.isCtrlDown(pressMods));
                        root.updateMarquee(mouse.x, mouse.y);
                    }
                    onReleased: mouse => {
                        // Starting Drag.active steals the grab and can fire released — don't cancel DnD
                        if (root.fileDragActive) {
                            pressHit = "";
                            pressItem = null;
                            return;
                        }

                        if (pressHit.length && !root.marqueeMoved)
                            root.clickSelectPath(pressHit, pressMods);

                        pressHit = "";
                        pressItem = null;
                        root.marqueePending = false;
                        if (root.marqueeActive)
                            root.endMarquee();
                    }
                    onCanceled: {
                        if (root.fileDragActive) {
                            pressHit = "";
                            pressItem = null;
                            return;
                        }
                        pressHit = "";
                        pressItem = null;
                        root.marqueePending = false;
                        if (root.marqueeActive)
                            root.endMarquee();
                    }
                    onDoubleClicked: mouse => {
                        const hit = root.hitFileAt(mouse.x, mouse.y);
                        if (!hit.length)
                            return;
                        const entry = session.filteredEntries.find(e => e.path === hit);
                        if (entry)
                            session.openEntry(entry);
                    }
                }

                // Right-click overlay (TapHandler does not steal scroll / left clicks)
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: (eventPoint, button) => {
                        const mx = eventPoint.position.x;
                        const my = eventPoint.position.y;
                        let entry = null;
                        if (session.listView && fileList.visible) {
                            const p = fileList.contentItem.mapFromItem(parent, mx, my);
                            const it = fileList.itemAt(p.x, p.y);
                            if (it && it.modelData)
                                entry = it.modelData;
                        } else if (fileGrid.visible) {
                            const p = fileGrid.contentItem.mapFromItem(parent, mx, my);
                            const it = fileGrid.itemAt(p.x, p.y);
                            if (it && it.modelData)
                                entry = it.modelData;
                        }
                        if (entry) {
                            if (!session.isSelected(entry.path))
                                session.selectOnly(entry.path);
                            root.openCtxMenu(parent, mx, my, "file");
                        } else {
                            session.clearSelection();
                            root.openCtxMenu(parent, mx, my, "folder");
                        }
                    }
                }

                Rectangle {
                    visible: root.marqueeActive
                    x: Math.min(root.marqueeOriginX, root.marqueeX)
                    y: Math.min(root.marqueeOriginY, root.marqueeY)
                    width: Math.abs(root.marqueeX - root.marqueeOriginX)
                    height: Math.abs(root.marqueeY - root.marqueeOriginY)
                    z: 50
                    color: Qt.alpha(Colours.palette.m3primary, 0.18)
                    border.width: 1
                    border.color: Colours.palette.m3primary
                    radius: Theme.Appearance.rounding.small
                    antialiasing: true
                }

                // Subtle listing spinner only (never block the window during extract/copy)
                Rectangle {
                    anchors.fill: parent
                    visible: session.busy && !FileManagerService.jobActive
                    color: Qt.alpha(Colours.palette.m3surface, 0.35)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "progress_activity"
                        color: Colours.palette.m3primary
                        font.pointSize: Theme.Appearance.font.size.extraLarge
                    }
                }
            }

        }
    }

    Loader {
        active: !root.sidebarExpanded && root.folderDragActive
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 250
        z: 1500
        sourceComponent: StyledRect {
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Appearance.padding.normal
                spacing: Theme.Appearance.spacing.small

                StyledText {
                    text: qsTr("Places")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                    font.weight: Font.Medium
                }

                PinnedPlacesBlock {
                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // File / folder properties
    Rectangle {
        id: propertiesScrim
        anchors.fill: parent
        visible: root.propertiesOpen
        z: 100
        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        readonly property var info: root.propertiesInfo || ({})
        readonly property var items: propertiesScrim.info.items || []
        readonly property var item: propertiesScrim.items.length === 1 ? propertiesScrim.items[0] : null

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeProperties()
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: Math.min(460, parent.width - 48)
            implicitHeight: Math.min(propertiesCol.implicitHeight + Theme.Appearance.padding.large * 2, parent.height - 48)
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Flickable {
                id: propertiesFlick
                anchors.fill: parent
                anchors.margins: Theme.Appearance.padding.large
                contentWidth: width
                contentHeight: propertiesCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: propertiesCol
                    width: propertiesFlick.width
                    spacing: Theme.Appearance.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const it = propertiesScrim.item;
                            if (!it)
                                return "info";
                            if (it.isDir)
                                return "folder";
                            if (it.isSymlink)
                                return "link";
                            return "draft";
                        }
                        color: Colours.palette.m3primary
                        font.pointSize: Theme.Appearance.font.size.extraLarge
                        fill: propertiesScrim.item && propertiesScrim.item.isDir ? 1 : 0
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const it = propertiesScrim.item;
                            if (it && it.name)
                                return it.name;
                            const n = propertiesScrim.items.length;
                            return n > 1 ? qsTr("%1 items").arg(n) : qsTr("Properties");
                        }
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                        font.pointSize: Theme.Appearance.font.size.larger
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurface
                    }

                    Item {
                        Layout.fillWidth: true
                        height: Theme.Appearance.spacing.small
                    }

                    PropRow {
                        label: qsTr("Type")
                        value: {
                            const it = propertiesScrim.item;
                            if (it)
                                return root.propertiesTypeLabel(it);
                            const files = propertiesScrim.info.selectedFiles || 0;
                            const dirs = propertiesScrim.info.selectedDirs || 0;
                            if (files && dirs)
                                return qsTr("Mixed");
                            if (dirs)
                                return qsTr("Folders");
                            return qsTr("Files");
                        }
                    }
                    PropRow {
                        label: qsTr("Size")
                        busy: root.propertiesBusy && !!(propertiesScrim.item && propertiesScrim.item.isDir)
                        value: {
                            const it = propertiesScrim.item;
                            const bytes = it ? (it.size || 0) : (propertiesScrim.info.totalSize || 0);
                            if (root.propertiesBusy && it && it.isDir && !bytes)
                                return "";
                            return FileManagerService.formatBytes(bytes);
                        }
                    }
                    PropRow {
                        label: qsTr("Contains")
                        busy: root.propertiesBusy && !!(propertiesScrim.item && propertiesScrim.item.isDir)
                        value: {
                            const it = propertiesScrim.item;
                            if (it && it.isDir) {
                                const files = it.fileCount || 0;
                                const dirs = it.dirCount || 0;
                                if (root.propertiesBusy && !files && !dirs)
                                    return "";
                                return qsTr("%1 files, %2 folders").arg(files).arg(dirs);
                            }
                            if (!it && propertiesScrim.items.length > 1)
                                return qsTr("%1 files, %2 folders").arg(propertiesScrim.info.selectedFiles || 0).arg(propertiesScrim.info.selectedDirs || 0);
                            return "";
                        }
                    }
                    PropRow {
                        label: qsTr("Location")
                        value: {
                            const it = propertiesScrim.item;
                            if (!it)
                                return session.currentPath || "";
                            if (it.path === "trash://" || String(it.path).startsWith("trash://"))
                                return qsTr("Trash");
                            return it.parent || "";
                        }
                    }
                    PropRow {
                        label: qsTr("Original")
                        value: (propertiesScrim.item && propertiesScrim.item.originalPath) ? propertiesScrim.item.originalPath : ""
                    }
                    PropRow {
                        label: qsTr("Link to")
                        value: (propertiesScrim.item && propertiesScrim.item.linkTarget) ? propertiesScrim.item.linkTarget : ""
                    }
                    PropRow {
                        label: qsTr("Modified")
                        value: propertiesScrim.item ? root.formatStamp(propertiesScrim.item.mtime) : ""
                    }
                    PropRow {
                        label: qsTr("Accessed")
                        value: propertiesScrim.item ? root.formatStamp(propertiesScrim.item.atime) : ""
                    }
                    PropRow {
                        label: qsTr("Permissions")
                        value: {
                            const it = propertiesScrim.item;
                            if (!it || !it.mode)
                                return "";
                            return it.modeOctal ? `${it.mode}  (${it.modeOctal})` : it.mode;
                        }
                    }
                    PropRow {
                        label: qsTr("Owner")
                        value: (propertiesScrim.item && propertiesScrim.item.owner) ? propertiesScrim.item.owner : ""
                    }
                    PropRow {
                        label: qsTr("Group")
                        value: (propertiesScrim.item && propertiesScrim.item.group) ? propertiesScrim.item.group : ""
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.Appearance.spacing.normal

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            implicitWidth: propertiesCloseLabel.implicitWidth + Theme.Appearance.padding.large * 2
                            implicitHeight: 36
                            radius: Theme.Appearance.rounding.full
                            color: Colours.palette.m3primary

                            StateLayer {
                                color: Colours.palette.m3onPrimary
                                function onClicked(): void {
                                    root.closeProperties();
                                }
                            }

                            StyledText {
                                id: propertiesCloseLabel
                                anchors.centerIn: parent
                                text: qsTr("Close")
                                color: Colours.palette.m3onPrimary
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    // Rename / new folder name
    Rectangle {
        id: renameScrim
        anchors.fill: parent
        visible: root.renameOpen
        z: 100
        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        function prepareRenameField(): void {
            const name = session.renameDraft;
            renameField.text = name;
            renameField.forceActiveFocus();

            let end = name.length;
            const entry = session.entries.find(e => e && e.path === session.renameTarget);
            const isDir = entry ? !!entry.isDir : false;
            if (!isDir) {
                const dot = name.lastIndexOf(".");
                // Keep extension unselected; treat leading-dot names (e.g. .gitignore) as no extension
                if (dot > 0)
                    end = dot;
            }

            renameField.select(0, end);
        }

        onVisibleChanged: {
            if (!visible) {
                renameFocusTimer.stop();
                return;
            }
            renameFocusTimer.restart();
        }

        Timer {
            id: renameFocusTimer
            interval: 16
            repeat: false
            onTriggered: renameScrim.prepareRenameField()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: session.cancelRename()
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: Math.min(480, parent.width - 48)
            implicitHeight: renameDialogCol.implicitHeight + Theme.Appearance.padding.large * 2
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: renameDialogCol
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "drive_file_rename_outline"
                    color: Colours.palette.m3primary
                    font.pointSize: Theme.Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Rename")
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: Theme.Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }

                StyledTextField {
                    id: renameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(implicitHeight, 40)
                    selectByMouse: true
                    persistentSelection: true
                    wrapMode: TextInput.NoWrap
                    onTextEdited: session.renameDraft = text
                    onAccepted: session.commitRename(text)
                    Keys.onEscapePressed: session.cancelRename()
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.Appearance.spacing.small
                    spacing: Theme.Appearance.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        implicitWidth: renameCancelLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                session.cancelRename();
                            }
                        }

                        StyledText {
                            id: renameCancelLabel
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: renameConfirmLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3primary

                        StateLayer {
                            color: Colours.palette.m3onPrimary
                            function onClicked(): void {
                                session.commitRename(renameField.text);
                            }
                        }

                        StyledText {
                            id: renameConfirmLabel
                            anchors.centerIn: parent
                            text: qsTr("Rename")
                            color: Colours.palette.m3onPrimary
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    // Empty Trash confirmation
    Rectangle {
        anchors.fill: parent
        visible: root.confirmEmptyTrashOpen
        z: 100
        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.confirmEmptyTrashOpen = false
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: Math.min(420, parent.width - 48)
            implicitHeight: emptyTrashDialogCol.implicitHeight + Theme.Appearance.padding.large * 2
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1

            ColumnLayout {
                id: emptyTrashDialogCol
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "delete_sweep"
                    color: Colours.palette.m3error
                    font.pointSize: Theme.Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Empty Trash?")
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: Theme.Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("All items in the Trash will be permanently deleted. This cannot be undone.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.Appearance.spacing.small
                    spacing: Theme.Appearance.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        implicitWidth: emptyTrashCancelLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.confirmEmptyTrashOpen = false;
                            }
                        }

                        StyledText {
                            id: emptyTrashCancelLabel
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: emptyTrashConfirmLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3error

                        StateLayer {
                            color: Colours.palette.m3onError
                            function onClicked(): void {
                                root.confirmEmptyTrashOpen = false;
                                session.emptyTrash();
                            }
                        }

                        StyledText {
                            id: emptyTrashConfirmLabel
                            anchors.centerIn: parent
                            text: qsTr("Empty Trash")
                            color: Colours.palette.m3onError
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    // Permanent delete confirmation
    Rectangle {
        anchors.fill: parent
        visible: root.confirmDeleteOpen
        z: 100
        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.confirmDeleteOpen = false
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: Math.min(420, parent.width - 48)
            implicitHeight: deleteDialogCol.implicitHeight + Theme.Appearance.padding.large * 2
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1

            ColumnLayout {
                id: deleteDialogCol
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "delete_forever"
                    color: Colours.palette.m3error
                    font.pointSize: Theme.Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Delete permanently?")
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: Theme.Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("%1 item(s) will be permanently deleted. This cannot be undone.").arg(session.selectedPaths.length)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Theme.Appearance.font.size.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.Appearance.spacing.small
                    spacing: Theme.Appearance.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        implicitWidth: cancelLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.confirmDeleteOpen = false;
                            }
                        }

                        StyledText {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: deleteLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3error

                        StateLayer {
                            color: Colours.palette.m3onError
                            function onClicked(): void {
                                root.confirmDeleteOpen = false;
                                session.deletePermanentSelection();
                            }
                        }

                        StyledText {
                            id: deleteLabel
                            anchors.centerIn: parent
                            text: qsTr("Delete")
                            color: Colours.palette.m3onError
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    // In-window toasts (status, jobs, copy/cut/trash)
    FmToastHost {
        id: fmToasts
        session: session
        anchors.fill: parent
    }
}
