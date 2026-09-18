pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config as Theme
import qs.utils
import qs.modules.utilities.toasts
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "Syntax.js" as Syntax
import "Markdown.js" as Markdown

Item {
    id: root

    signal requestClose
    signal requestForceClose

    property string startPath: ""
    property string filePath: ""
    property bool dirty: false
    property bool loading: false
    property bool pendingClose: false
    property bool confirmOpen: false
    property bool saveAsOpen: false
    property string loadedText: ""
    property var pendingSaveText: null
    property string highlightedHtml: ""
    property string indentStr: "    "

    readonly property string language: TextEditorService.languageFor(root.filePath)
    readonly property bool syntaxOn: root.language.length > 0
    readonly property bool isMarkdown: root.language === "md" || root.language === "mdx"
    property string mdView: "preview"
    property var previewBlocks: []

    readonly property bool sourceVisible: !root.isMarkdown || root.mdView === "source" || root.mdView === "split"
    readonly property bool previewVisible: root.isMarkdown && (root.mdView === "preview" || root.mdView === "split")

    onLanguageChanged: root.refreshHighlight()

    readonly property string fileLabel: {
        const name = TextEditorService.fileName(root.filePath);
        return name.length ? name : qsTr("Untitled");
    }

    readonly property string windowTitle: {
        const mark = root.dirty ? " •" : "";
        return `${root.fileLabel}${mark} — Text`;
    }

    function cssColor(c: color): string {
        const col = Qt.color(c);
        const hex = n => Math.max(0, Math.min(255, Math.round(n * 255))).toString(16).padStart(2, "0");
        return `#${hex(col.r)}${hex(col.g)}${hex(col.b)}`;
    }

    function syntaxColors(): var {
        return {
            key: root.cssColor(Colours.palette.m3primary),
            string: root.cssColor(Colours.palette.m3tertiary),
            number: root.cssColor(Colours.palette.m3secondary),
            keyword: root.cssColor(Colours.palette.m3secondary),
            comment: root.cssColor(Colours.palette.m3outline),
            punct: root.cssColor(Colours.palette.m3onSurfaceVariant),
            section: root.cssColor(Colours.palette.m3primary),
            fg: root.cssColor(Colours.palette.m3onSurface)
        };
    }

    function refreshHighlight(): void {
        if (!root.syntaxOn) {
            root.highlightedHtml = "";
        } else {
            root.highlightedHtml = Syntax.highlight(editor.text, root.language, root.syntaxColors());
        }
        if (!root.isMarkdown) {
            root.previewBlocks = [];
            return;
        }
        const blocks = root.buildPreview(editor.text);
        root.previewBlocks = blocks || [];
    }

    function buildPreview(text: string): var {
        const dir = root.filePath.slice(0, Math.max(0, root.filePath.lastIndexOf("/")));
        const size = Math.max(13, Theme.Appearance.font.size.normal);
        try {
            return Markdown.mdToBlocks(text, {
                fg: root.cssColor(Colours.palette.m3onSurface),
                heading: root.cssColor(Colours.palette.m3onSurface),
                muted: root.cssColor(Colours.palette.m3onSurfaceVariant),
                codeBg: root.cssColor(Colours.palette.m3secondaryContainer),
                codeFg: root.cssColor(Colours.palette.m3onSurfaceVariant),
                link: root.cssColor(Colours.palette.m3primary),
                quoteBar: root.cssColor(Colours.palette.m3primary),
                mono: Theme.Appearance.font.family.mono,
                sans: Theme.Appearance.font.family.sans,
                size: size
            }, {
                dir: dir,
                mdx: root.language === "mdx"
            });
        } catch (e) {
            return [];
        }
    }

    function detectIndent(text: string): string {
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (line.startsWith("\t"))
                return "\t";
            const m = line.match(/^( +)/);
            if (!m)
                continue;
            const n = m[1].length;
            if (n === 2 || n === 4)
                return m[1].slice(0, n);
            if (n > 1)
                return n % 4 === 0 ? "    " : "  ";
        }
        return root.language === "json" || root.language === "yaml" || root.language === "md" || root.language === "mdx" ? "  " : "    ";
    }

    function maybeFormat(text: string): string {
        if (root.language !== "json")
            return text;
        const src = String(text || "");
        if (src.indexOf("\n") >= 0)
            return src;
        try {
            return JSON.stringify(JSON.parse(src), null, root.indentStr === "\t" ? "\t" : 2) + "\n";
        } catch (e) {
            return src;
        }
    }

    function lineStartAt(text: string, pos: int): int {
        const i = text.lastIndexOf("\n", Math.max(0, pos - 1));
        return i < 0 ? 0 : i + 1;
    }

    function lineEndAt(text: string, pos: int): int {
        const i = text.indexOf("\n", pos);
        return i < 0 ? text.length : i;
    }

    function indentBlock(unindent: bool): void {
        const t = editor.text;
        let a = editor.selectionStart;
        let b = editor.selectionEnd;
        if (a > b) {
            const x = a;
            a = b;
            b = x;
        }
        const unit = root.indentStr;
        if (a === b) {
            if (unindent) {
                const from = root.lineStartAt(t, a);
                const line = t.slice(from, a);
                if (line.endsWith(unit)) {
                    editor.remove(a - unit.length, a);
                    return;
                }
                const lead = t.slice(from, root.lineEndAt(t, a));
                if (lead.startsWith(unit)) {
                    editor.remove(from, from + unit.length);
                    return;
                }
                if (lead.startsWith("\t")) {
                    editor.remove(from, from + 1);
                    return;
                }
                const m = lead.match(/^ {1,4}/);
                if (m)
                    editor.remove(from, from + m[0].length);
                return;
            }
            editor.insert(editor.cursorPosition, unit);
            return;
        }
        const from = root.lineStartAt(t, a);
        const to = root.lineEndAt(t, b);
        const block = t.slice(from, to);
        const lines = block.split("\n");
        for (let i = 0; i < lines.length; ++i) {
            if (unindent) {
                if (lines[i].startsWith(unit))
                    lines[i] = lines[i].slice(unit.length);
                else if (lines[i].startsWith("\t"))
                    lines[i] = lines[i].slice(1);
                else
                    lines[i] = lines[i].replace(/^ {1,4}/, "");
            } else {
                lines[i] = unit + lines[i];
            }
        }
        const next = lines.join("\n");
        editor.remove(from, to);
        editor.insert(from, next);
        editor.select(from, from + next.length);
    }

    function handleEnter(): void {
        const t = editor.text;
        const pos = editor.cursorPosition;
        const from = root.lineStartAt(t, pos);
        const line = t.slice(from, pos);
        const indent = (line.match(/^[ \t]*/) || [""])[0];
        const trimmed = line.trimEnd();
        const unit = root.indentStr;
        const next = t.slice(pos);
        if (root.isMarkdown) {
            const list = line.match(/^(\s*)([-*+]|\d+\.)(\s+)/);
            if (list) {
                const rest = line.slice(list[0].length);
                if (!String(rest).trim().length) {
                    editor.remove(from, pos);
                    editor.insert(from, "\n");
                    return;
                }
                let bullet = list[2];
                if (/^\d/.test(bullet))
                    bullet = `${parseInt(bullet, 10) + 1}.`;
                editor.insert(pos, `\n${list[1]}${bullet}${list[3]}`);
                return;
            }
        }
        const closer = next.match(/^\s*([}\]])/);
        if (/[\[{]$/.test(trimmed)) {
            if (closer) {
                editor.insert(pos, `\n${indent}${unit}\n${indent}`);
                editor.cursorPosition = pos + 1 + indent.length + unit.length;
            } else {
                editor.insert(pos, `\n${indent}${unit}`);
            }
            return;
        }
        if (/^\s*[}\]]/.test(next) && indent.endsWith(unit))
            editor.insert(pos, `\n${indent.slice(0, indent.length - unit.length)}`);
        else
            editor.insert(pos, `\n${indent}`);
    }

    function loadPath(path: string): void {
        const p = TextEditorService.normalizePath(path);
        root.filePath = p;
        root.pendingSaveText = null;
        if (!p.length) {
            fileView.path = "";
            root.applyLoaded("");
            return;
        }
        root.loading = true;
        editor.text = "";
        loadFallback.restart();
        if (fileView.path === p)
            fileView.reload();
        else
            fileView.path = p;
    }

    function askClose(): void {
        if (!root.dirty) {
            root.requestForceClose();
            return;
        }
        root.pendingClose = true;
        root.confirmOpen = true;
    }

    function save(): bool {
        if (!root.filePath.length) {
            root.saveAsOpen = true;
            Qt.callLater(() => saveAsField.forceActiveFocus());
            return false;
        }
        root.pendingSaveText = editor.text;
        if (fileView.path !== root.filePath)
            fileView.path = root.filePath;
        fileView.setText(editor.text);
        return true;
    }

    function saveTo(path: string): void {
        const p = TextEditorService.normalizePath(path);
        if (!p.length)
            return;
        root.filePath = p;
        root.pendingSaveText = editor.text;
        fileView.path = p;
        fileView.setText(editor.text);
    }

    function confirmSaveAs(): void {
        const raw = String(saveAsField.text || "").trim();
        if (!raw.length)
            return;
        const p = raw.startsWith("/") || raw.startsWith("~") ? TextEditorService.normalizePath(raw) : `${Paths.home}/${raw}`;
        root.saveAsOpen = false;
        root.saveTo(p);
    }

    function applyLoaded(text: string): void {
        loadFallback.stop();
        root.indentStr = root.detectIndent(text);
        const formatted = root.maybeFormat(text);
        root.loading = true;
        editor.text = formatted;
        root.loadedText = formatted;
        root.dirty = formatted !== text;
        root.loading = false;
        root.refreshHighlight();
        Qt.callLater(() => {
            editor.cursorPosition = 0;
            editor.forceActiveFocus();
            flick.contentY = 0;
            flick.contentX = 0;
        });
    }

    Component.onCompleted: root.loadPath(root.startPath)

    Timer {
        id: loadFallback
        interval: 120
        repeat: false
        onTriggered: {
            if (!root.loading || !root.filePath.length)
                return;
            readProc.running = false;
            readProc.command = ["cat", "--", root.filePath];
            readProc.running = true;
        }
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: root.applyLoaded(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err.length)
                    Toaster.toast(qsTr("Could not open file"), err, "error", Toast.Error);
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.loading = false;
        }
    }

    FileView {
        id: fileView
        preload: true
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.pendingSaveText !== null)
                return;
            root.applyLoaded(text() || "");
        }
        onLoadFailed: err => {
            if (!root.filePath.length) {
                root.applyLoaded("");
                return;
            }
            if (err === FileViewError.FileNotFound) {
                root.applyLoaded("");
                return;
            }
            readProc.running = false;
            readProc.command = ["cat", "--", root.filePath];
            readProc.running = true;
        }
        onSaved: {
            root.pendingSaveText = null;
            root.loadedText = editor.text;
            root.dirty = false;
            if (root.pendingClose)
                root.requestForceClose();
        }
        onSaveFailed: err => {
            root.pendingSaveText = null;
            root.pendingClose = false;
            Toaster.toast(qsTr("Could not save file"), FileViewError.toString(err), "error", Toast.Error);
        }
    }

    Shortcut {
        sequences: [StandardKey.Save]
        context: Qt.WindowShortcut
        onActivated: root.save()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+S"]
        context: Qt.WindowShortcut
        onActivated: {
            saveAsField.text = root.filePath.length ? root.filePath : `${Paths.home}/untitled.txt`;
            root.saveAsOpen = true;
            Qt.callLater(() => saveAsField.forceActiveFocus());
        }
    }
    Shortcut {
        sequences: [StandardKey.Close, StandardKey.Quit, "Ctrl+W"]
        context: Qt.WindowShortcut
        onActivated: root.requestClose()
    }
    Shortcut {
        sequences: [StandardKey.New]
        context: Qt.WindowShortcut
        onActivated: TextEditorService.open("")
    }
    Shortcut {
        sequences: ["Escape"]
        context: Qt.WindowShortcut
        enabled: root.confirmOpen || root.saveAsOpen
        onActivated: {
            root.confirmOpen = false;
            root.saveAsOpen = false;
            root.pendingClose = false;
        }
    }

    Timer {
        id: highlightTimer
        interval: 24
        repeat: false
        onTriggered: root.refreshHighlight()
    }

    Shortcut {
        sequences: ["Ctrl+]"]
        context: Qt.WindowShortcut
        onActivated: root.indentBlock(false)
    }
    Shortcut {
        sequences: ["Ctrl+["]
        context: Qt.WindowShortcut
        onActivated: root.indentBlock(true)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+P"]
        context: Qt.WindowShortcut
        enabled: root.isMarkdown
        onActivated: {
            root.mdView = root.mdView === "preview" ? "source" : "preview";
        }
    }

    component MdChip: StyledRect {
        id: chip
        property string label: ""
        property bool active: false
        signal activated
        implicitWidth: chipLabel.implicitWidth + Theme.Appearance.padding.large * 2
        implicitHeight: 32
        radius: Theme.Appearance.rounding.full
        color: chip.active ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHighest
        StateLayer {
            color: chip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            function onClicked(): void {
                chip.activated();
            }
        }
        StyledText {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            font.pointSize: Theme.Appearance.font.size.small
            font.weight: chip.active ? Font.Medium : Font.Normal
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Appearance.padding.normal
        spacing: Theme.Appearance.spacing.small

        Row {
            visible: root.isMarkdown
            Layout.fillWidth: true
            spacing: Theme.Appearance.spacing.small

            MdChip {
                label: qsTr("Preview")
                active: root.mdView === "preview"
                onActivated: root.mdView = "preview"
            }
            MdChip {
                label: qsTr("Source")
                active: root.mdView === "source"
                onActivated: root.mdView = "source"
            }
            MdChip {
                label: qsTr("Split")
                active: root.mdView === "split"
                onActivated: root.mdView = "split"
            }
        }

        RowLayout {
            id: editorRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.Appearance.spacing.small

            Item {
                visible: root.sourceVisible
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                implicitWidth: 0
                implicitHeight: 0
                clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: root.syntaxOn ? Flickable.HorizontalAndVerticalFlick : Flickable.VerticalFlick
                contentWidth: root.syntaxOn ? Math.max(width, editor.width) : width
                contentHeight: Math.max(height, editor.height)

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: flick
                }

                Text {
                    id: colorLayer
                    x: editor.x
                    y: editor.y
                    width: Math.max(editor.contentWidth, editor.width)
                    height: Math.max(editor.contentHeight, editor.height)
                    visible: root.syntaxOn
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    text: root.highlightedHtml
                    color: Colours.palette.m3onSurface
                    renderType: Text.QtRendering
                    font.family: editor.font.family
                    font.pointSize: editor.font.pointSize
                    font.hintingPreference: Font.PreferFullHinting
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    z: 0
                }

                TextEdit {
                    id: editor
                    width: root.syntaxOn ? Math.max(flick.width, contentWidth) : flick.width
                    height: Math.max(contentHeight, flick.height)
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    textFormat: TextEdit.PlainText
                    wrapMode: root.syntaxOn ? TextEdit.NoWrap : TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    activeFocusOnPress: true
                    color: root.syntaxOn ? "transparent" : Colours.palette.m3onSurface
                    selectedTextColor: root.syntaxOn ? "transparent" : Colours.palette.m3onPrimary
                    selectionColor: root.syntaxOn ? Qt.alpha(Colours.palette.m3primary, 0.28) : Colours.palette.m3primary
                    renderType: Text.QtRendering
                    font.family: Theme.Appearance.font.family.mono
                    font.pointSize: Math.max(12, Theme.Appearance.font.size.smaller)
                    font.hintingPreference: Font.PreferFullHinting
                    tabStopDistance: Math.max(16, font.pixelSize * root.indentStr.length)
                    z: 1
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Colours.palette.m3primary
                        visible: editor.activeFocus
                    }
                    onTextChanged: {
                        if (root.loading)
                            return;
                        root.dirty = editor.text !== root.loadedText;
                        if (root.syntaxOn || root.isMarkdown)
                            highlightTimer.restart();
                    }
                    onCursorRectangleChanged: {
                        const r = cursorRectangle;
                        if (r.y < flick.contentY)
                            flick.contentY = Math.max(0, r.y);
                        else if (r.y + r.height > flick.contentY + flick.height)
                            flick.contentY = Math.max(0, r.y + r.height - flick.height);
                        if (root.syntaxOn) {
                            if (r.x < flick.contentX)
                                flick.contentX = Math.max(0, r.x);
                            else if (r.x + r.width > flick.contentX + flick.width)
                                flick.contentX = Math.max(0, r.x + r.width - flick.width);
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backtab) {
                            root.indentBlock(true);
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Tab) {
                            root.indentBlock(false);
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.handleEnter();
                            event.accepted = true;
                        }
                    }
                }
            }
            }

            Rectangle {
                visible: root.sourceVisible && root.previewVisible
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: 1
                width: 1
                color: Colours.palette.m3outlineVariant
                opacity: 0.45
            }

            Item {
                visible: root.previewVisible
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                implicitWidth: 0
                implicitHeight: 0
                clip: true

                MarkdownPreview {
                    id: previewFlick
                    anchors.fill: parent
                    blocks: root.previewBlocks
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.confirmOpen || root.saveAsOpen
        z: 100
        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.confirmOpen = false;
                root.saveAsOpen = false;
                root.pendingClose = false;
            }
        }

        StyledRect {
            visible: root.confirmOpen
            anchors.centerIn: parent
            implicitWidth: Math.min(420, parent.width - 48)
            implicitHeight: confirmCol.implicitHeight + Theme.Appearance.padding.large * 2
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1

            ColumnLayout {
                id: confirmCol
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Save changes?")
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: Theme.Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("%1 has unsaved changes.").arg(root.fileLabel)
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
                        implicitWidth: discardLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.confirmOpen = false;
                                root.pendingClose = false;
                                root.requestForceClose();
                            }
                        }

                        StyledText {
                            id: discardLabel
                            anchors.centerIn: parent
                            text: qsTr("Discard")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: cancelCloseLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.confirmOpen = false;
                                root.pendingClose = false;
                            }
                        }

                        StyledText {
                            id: cancelCloseLabel
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: saveLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3primary

                        StateLayer {
                            color: Colours.palette.m3onPrimary
                            function onClicked(): void {
                                root.confirmOpen = false;
                                if (!root.save())
                                    root.pendingClose = true;
                            }
                        }

                        StyledText {
                            id: saveLabel
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            color: Colours.palette.m3onPrimary
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        StyledRect {
            visible: root.saveAsOpen
            anchors.centerIn: parent
            implicitWidth: Math.min(520, parent.width - 48)
            implicitHeight: saveAsCol.implicitHeight + Theme.Appearance.padding.large * 2
            radius: Theme.Appearance.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            z: 1

            ColumnLayout {
                id: saveAsCol
                x: Theme.Appearance.padding.large
                y: Theme.Appearance.padding.large
                width: parent.width - Theme.Appearance.padding.large * 2
                spacing: Theme.Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Save as")
                    font.pointSize: Theme.Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }

                StyledTextField {
                    id: saveAsField
                    Layout.fillWidth: true
                    text: root.filePath.length ? root.filePath : `${Paths.home}/untitled.txt`
                    onAccepted: root.confirmSaveAs()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Appearance.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        implicitWidth: cancelSaveAsLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                root.saveAsOpen = false;
                                if (!root.filePath.length)
                                    root.pendingClose = false;
                            }
                        }

                        StyledText {
                            id: cancelSaveAsLabel
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        implicitWidth: saveAsLabel.implicitWidth + Theme.Appearance.padding.large * 2
                        implicitHeight: 36
                        radius: Theme.Appearance.rounding.full
                        color: Colours.palette.m3primary

                        StateLayer {
                            color: Colours.palette.m3onPrimary
                            function onClicked(): void {
                                root.confirmSaveAs();
                            }
                        }

                        StyledText {
                            id: saveAsLabel
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            color: Colours.palette.m3onPrimary
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
