pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import qs.modules.utilities.toasts
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string appId: "donwaztok-text"
    readonly property string desktopFile: "donwaztok-text.desktop"
    readonly property string appName: "Donwaztok Text"

    readonly property string desktopPath: `${Paths.home}/.local/share/applications/${desktopFile}`

    readonly property list<string> defaultMimes: [
        "text/plain",
        "text/markdown",
        "text/x-markdown",
        "text/mdx",
        "text/x-mdx",
        "text/csv",
        "text/tab-separated-values",
        "text/xml",
        "text/css",
        "text/javascript",
        "text/x-python",
        "text/x-shellscript",
        "text/x-script.python",
        "text/x-c",
        "text/x-c++src",
        "text/x-c++hdr",
        "text/x-java",
        "text/x-java-source",
        "text/rust",
        "text/x-rust",
        "text/x-go",
        "text/x-lua",
        "text/x-qml",
        "text/x-cmake",
        "text/x-makefile",
        "text/x-patch",
        "text/x-diff",
        "text/x-log",
        "text/yaml",
        "text/x-yaml",
        "text/x-toml",
        "text/x-ini",
        "application/json",
        "application/schema+json",
        "application/xml",
        "application/x-yaml",
        "application/toml",
        "application/javascript",
        "application/x-javascript",
        "application/sql",
        "application/x-desktop",
        "application/x-shellscript",
        "application/x-ruby",
        "inode/x-empty"
    ]

    readonly property var textExts: ({
        "txt": true,
        "text": true,
        "md": true,
        "markdown": true,
        "mdx": true,
        "rst": true,
        "log": true,
        "csv": true,
        "tsv": true,
        "json": true,
        "jsonc": true,
        "json5": true,
        "toml": true,
        "yaml": true,
        "yml": true,
        "ini": true,
        "conf": true,
        "cfg": true,
        "cnf": true,
        "env": true,
        "properties": true,
        "desktop": true,
        "service": true,
        "timer": true,
        "xml": true,
        "qml": true,
        "js": true,
        "mjs": true,
        "cjs": true,
        "ts": true,
        "tsx": true,
        "jsx": true,
        "css": true,
        "scss": true,
        "less": true,
        "py": true,
        "pyw": true,
        "rb": true,
        "rs": true,
        "go": true,
        "c": true,
        "h": true,
        "cc": true,
        "cpp": true,
        "cxx": true,
        "hpp": true,
        "hh": true,
        "java": true,
        "kt": true,
        "kts": true,
        "cs": true,
        "sh": true,
        "bash": true,
        "zsh": true,
        "fish": true,
        "ps1": true,
        "lua": true,
        "pl": true,
        "pm": true,
        "r": true,
        "sql": true,
        "vue": true,
        "svelte": true,
        "gradle": true,
        "cmake": true,
        "nix": true,
        "vim": true,
        "diff": true,
        "patch": true,
        "gitignore": true,
        "dockerignore": true,
        "editorconfig": true,
        "gpl": true,
        "license": true
    })

    readonly property var textNames: ({
        "makefile": true,
        "dockerfile": true,
        "license": true,
        "licence": true,
        "copying": true,
        "readme": true,
        "changelog": true,
        "authors": true,
        "cmakelists.txt": true,
        "gemfile": true,
        "procfile": true,
        ".gitignore": true,
        ".gitmodules": true,
        ".gitattributes": true,
        ".editorconfig": true,
        ".env": true,
        ".bashrc": true,
        ".zshrc": true,
        ".profile": true,
        ".vimrc": true
    })

    signal requestOpen(string path)

    readonly property string editorId: {
        const v = Config.general.apps.editor;
        if (!v || !String(v).length)
            return root.appId;
        return String(v);
    }

    readonly property bool isDefault: editorId === root.appId

    readonly property string desktopEntryText: {
        const exec = "qs -c donwaztok ipc call textEditor open %f";
        let mimes = "";
        for (let i = 0; i < root.defaultMimes.length; ++i)
            mimes += root.defaultMimes[i] + ";";
        return "[Desktop Entry]\n" + "Type=Application\n" + "Name=Donwaztok Text\n" + "GenericName=Text Editor\n" + "Comment=Simple text editor\n" + "Exec=" + exec + "\n" + "Icon=accessories-text-editor\n" + "Terminal=false\n" + "StartupNotify=false\n" + "Categories=Utility;TextEditor;\n" + "MimeType=" + mimes + "\n" + "Keywords=text;editor;notes;plain;\n";
    }

    function normalizePath(path: string): string {
        let p = String(path || "");
        if (p.startsWith("file://"))
            p = p.slice("file://".length);
        if (p.startsWith("//")) {
            const slash = p.indexOf("/", 2);
            p = slash >= 0 ? p.slice(slash) : p;
        }
        try {
            p = decodeURIComponent(p);
        } catch (e) {}
        if (p.startsWith("~"))
            p = (Paths.home || "") + p.slice(1);
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.endsWith("/"))
            p = p.replace(/\/+$/, "");
        return p;
    }

    function fileName(path: string): string {
        const p = root.normalizePath(path);
        if (!p.length)
            return "";
        const i = p.lastIndexOf("/");
        return i >= 0 ? p.slice(i + 1) : p;
    }

    function languageFor(path: string): string {
        const name = root.fileName(path).toLowerCase();
        if (!name.length)
            return "";
        const dot = name.lastIndexOf(".");
        const ext = dot >= 0 ? name.slice(dot + 1) : "";
        if (ext === "json" || ext === "jsonc" || ext === "json5")
            return "json";
        if (ext === "md" || ext === "markdown" || ext === "mdx")
            return ext === "mdx" ? "mdx" : "md";
        if (ext === "toml")
            return "ini";
        if (ext === "yaml" || ext === "yml")
            return "yaml";
        if (ext === "sh" || ext === "bash" || ext === "zsh" || ext === "fish" || ext === "ksh" || ext === "csh")
            return "sh";
        if (name === ".bashrc" || name === ".bash_profile" || name === ".bash_login" || name === ".bash_logout" || name === ".zshrc" || name === ".zprofile" || name === ".zshenv" || name === ".zlogin" || name === ".zlogout" || name === ".profile" || name === ".xprofile" || name === "bashrc" || name === "zshrc" || name === "profile")
            return "sh";
        if (ext === "ini" || ext === "conf" || ext === "cfg" || ext === "cnf" || ext === "env" || ext === "desktop" || ext === "properties" || ext === "service" || ext === "timer")
            return "ini";
        if (name === "config" || name === "mimeapps.list" || name.endsWith("rc"))
            return "ini";
        return "";
    }

    function isTextFile(path: string): bool {
        const p = root.normalizePath(path);
        if (!p.length)
            return false;
        const name = root.fileName(p);
        const lower = name.toLowerCase();
        if (root.textNames[lower])
            return true;
        const dot = lower.lastIndexOf(".");
        if (dot <= 0)
            return false;
        return !!root.textExts[lower.slice(dot + 1)];
    }

    function isTextMime(mime: string): bool {
        const m = String(mime || "").toLowerCase();
        if (!m.length)
            return false;
        if (m === "text/html" || m === "text/htmlh")
            return false;
        if (m.startsWith("text/"))
            return true;
        const list = root.defaultMimes;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] === m)
                return true;
        }
        return false;
    }

    function shouldOpenInternally(path: string, mime: string): bool {
        if (!root.isDefault)
            return false;
        if (root.isTextMime(mime))
            return true;
        return root.isTextFile(path);
    }

    function open(path: string): void {
        root.ensureDesktopEntry();
        root.requestOpen(root.normalizePath(path));
    }

    function desktopName(appId: string): string {
        const id = String(appId || "").trim();
        if (!id.length)
            return "";
        return id.endsWith(".desktop") ? id : `${id}.desktop`;
    }

    function openWith(appId: string, paths: var): void {
        const list = [];
        if (typeof paths === "string") {
            const p = root.normalizePath(paths);
            if (p.length)
                list.push(p);
        } else if (paths && paths.length) {
            for (let i = 0; i < paths.length; ++i) {
                const p = root.normalizePath(String(paths[i] || ""));
                if (p.length)
                    list.push(p);
            }
        }
        if (!list.length)
            return;

        const id = String(appId || "").trim();
        if (!id.length || id === root.appId) {
            for (let i = 0; i < list.length; ++i)
                root.open(list[i]);
            return;
        }

        const desk = root.desktopName(id);
        Quickshell.execDetached(["gio", "launch", desk].concat(list));
    }

    function listOpenWithApps(): var {
        const out = [
            {
                id: root.appId,
                name: root.appName
            }
        ];
        const seen = {};
        seen[root.appId] = true;
        seen[root.desktopFile] = true;

        let values = [];
        try {
            const model = DesktopEntries.applications;
            const raw = model && model.values ? model.values : [];
            values = Array.from(raw);
        } catch (e) {
            values = [];
        }

        const editors = [];
        const others = [];
        for (let i = 0; i < values.length; ++i) {
            const e = values[i];
            if (!e || e.noDisplay)
                continue;
            const id = String(e.id || "");
            if (!id.length || seen[id])
                continue;
            seen[id] = true;
            const name = String(e.name || id);
            const row = {
                id: id,
                name: name
            };
            if (root.isEditorApp(e))
                editors.push(row);
            else
                others.push(row);
        }
        const byName = (a, b) => String(a.name).localeCompare(String(b.name));
        editors.sort(byName);
        others.sort(byName);
        return out.concat(editors, others);
    }

    function isEditorApp(entry: var): bool {
        if (!entry)
            return false;
        try {
            const cats = entry.categories || [];
            for (let c = 0; c < cats.length; ++c) {
                const cat = String(cats[c] || "");
                if (cat === "TextEditor" || cat === "Development")
                    return true;
            }
        } catch (e) {}
        return false;
    }

    function editorOptions(): var {
        const out = [
            {
                text: root.appName,
                value: root.appId
            },
            {
                text: qsTr("System default"),
                value: "system"
            }
        ];
        const seen = {
            system: true
        };
        seen[root.appId] = true;
        const model = DesktopEntries.applications;
        const values = model && model.values ? model.values : [];
        const editors = [];
        for (let i = 0; i < values.length; ++i) {
            const e = values[i];
            if (!e || e.noDisplay || seen[e.id] || !root.isEditorApp(e))
                continue;
            seen[e.id] = true;
            editors.push({
                text: String(e.name || e.id),
                value: String(e.id)
            });
        }
        editors.sort((a, b) => a.text.localeCompare(b.text));
        const current = root.editorId;
        if (current && !seen[current]) {
            const entry = DesktopEntries.byId(current);
            out.push({
                text: entry && entry.name ? entry.name : current,
                value: current
            });
        }
        return out.concat(editors);
    }

    function setDefaultEditor(id: string): void {
        const value = String(id || root.appId).trim() || root.appId;
        Config.general.apps.editor = value;
        Config.save();
        root.ensureDesktopEntry();
        if (value === "system")
            return;
        root.applyMimeDefault(value === root.appId ? root.desktopFile : root.desktopName(value));
    }

    function ensureDesktopEntry(): void {
        const dir = `${Paths.home}/.local/share/applications`;
        Quickshell.execDetached(["mkdir", "-p", dir]);
        desktopFileView.path = root.desktopPath;
        desktopFileView.setText(root.desktopEntryText);
        Quickshell.execDetached(["update-desktop-database", dir]);
    }

    function applyMimeDefault(desktop: string): void {
        const desk = root.desktopName(desktop);
        if (!desk.length)
            return;
        const parts = [];
        const mimes = root.defaultMimes;
        for (let i = 0; i < mimes.length; ++i)
            parts.push(`xdg-mime default '${desk}' '${mimes[i]}'`);
        mimeProc.command = ["bash", "-lc", parts.join("; ")];
        mimeProc.running = true;
    }

    property int appsVersion: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            root.appsVersion += 1;
        }
    }

    readonly property var editorOptionList: {
        root.appsVersion;
        root.editorId;
        return root.editorOptions();
    }

    function adoptDefaultEditor(): void {
        const id = String(Config.general.apps.editor || "");
        if (!id.length)
            root.setDefaultEditor(root.appId);
        else if (id === root.appId)
            root.applyMimeDefault(root.desktopFile);
    }

    Connections {
        target: DonwaztokConfigStore
        function onReadyChanged(): void {
            if (DonwaztokConfigStore.ready)
                root.adoptDefaultEditor();
        }
    }

    Component.onCompleted: {
        root.ensureDesktopEntry();
        if (DonwaztokConfigStore.ready)
            root.adoptDefaultEditor();
    }

    FileView {
        id: desktopFileView
        printErrors: false
        atomicWrites: true
        preload: false
    }

    Process {
        id: mimeProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Toaster.toast(qsTr("Could not set default editor"), qsTr("xdg-mime exited with code %1").arg(exitCode), "error", Toast.Warning);
        }
    }
}
