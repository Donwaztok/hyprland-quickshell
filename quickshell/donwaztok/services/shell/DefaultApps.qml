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

    readonly property string filesAppId: "donwaztok-files"
    readonly property string filesDesktopFile: "donwaztok-files.desktop"
    readonly property string filesAppName: "Donwaztok Files"
    readonly property string filesDesktopPath: `${Paths.home}/.local/share/applications/${filesDesktopFile}`
    readonly property string terminalsListPath: `${Paths.home}/.config/xdg-terminals.list`
    readonly property list<string> filesMimes: ["inode/directory", "inode/mount-point", "x-scheme-handler/trash"]
    readonly property list<string> playbackMimes: [
        "audio/mpeg",
        "audio/mp4",
        "audio/ogg",
        "audio/flac",
        "audio/x-wav",
        "audio/x-vorbis+ogg",
        "audio/x-flac",
        "audio/webm",
        "audio/aac",
        "video/mp4",
        "video/x-matroska",
        "video/webm",
        "video/quicktime",
        "video/x-msvideo",
        "video/mpeg",
        "application/ogg"
    ]

    property int appsVersion: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            root.appsVersion += 1;
        }
    }

    readonly property var terminalOptionList: {
        root.appsVersion;
        return root.optionsFor("terminal");
    }
    readonly property var explorerOptionList: {
        root.appsVersion;
        return root.optionsFor("explorer");
    }
    readonly property var audioOptionList: {
        root.appsVersion;
        return root.optionsFor("audio");
    }
    readonly property var playbackOptionList: {
        root.appsVersion;
        return root.optionsFor("playback");
    }

    readonly property string terminalId: root.idFromCommand(Config.general.apps.terminal, "terminal")
    readonly property string explorerId: root.idFromCommand(Config.general.apps.explorer, "explorer")
    readonly property string audioId: root.idFromCommand(Config.general.apps.audio, "audio")
    readonly property string playbackId: root.idFromCommand(Config.general.apps.playback, "playback")

    function binName(path: string): string {
        const s = String(path || "");
        const i = s.lastIndexOf("/");
        return i >= 0 ? s.slice(i + 1) : s;
    }

    function desktopName(appId: string): string {
        const id = String(appId || "").trim();
        if (!id.length || id === "system")
            return "";
        return id.endsWith(".desktop") ? id : `${id}.desktop`;
    }

    function isFilesCommand(cmd: var): bool {
        if (!cmd || !cmd.length)
            return false;
        for (let i = 0; i < cmd.length; ++i) {
            if (String(cmd[i]) === "fileManager" || String(cmd[i]) === root.filesAppId)
                return true;
        }
        return root.binName(cmd[0]) === root.filesAppId;
    }

    function isSystemCommand(cmd: var): bool {
        if (!cmd || !cmd.length)
            return true;
        const bin = root.binName(cmd[0]);
        return bin === "system" || bin === "xdg-open" || bin === "xdg-terminal-exec";
    }

    function hasCategory(entry: var, names: var): bool {
        if (!entry)
            return false;
        try {
            const cats = entry.categories || [];
            for (let i = 0; i < cats.length; ++i) {
                if (names[String(cats[i] || "")])
                    return true;
            }
        } catch (e) {}
        return false;
    }

    function matchesBin(entry: var, bin: string): bool {
        if (!entry || !bin.length)
            return false;
        const id = root.binName(String(entry.id || "")).replace(/\.desktop$/, "");
        if (id === bin)
            return true;
        try {
            const cmd = entry.command || [];
            if (cmd.length && root.binName(cmd[0]) === bin)
                return true;
        } catch (e) {}
        return false;
    }

    function isTerminalApp(entry: var): bool {
        if (!entry)
            return false;
        if (root.hasCategory(entry, {
                    "TerminalEmulator": true
                }))
            return true;
        const bin = root.binName(String(entry.id || "")).replace(/\.desktop$/, "");
        return bin === "kitty" || bin === "alacritty" || bin === "foot" || bin === "ghostty" || bin === "wezterm" || bin === "konsole" || bin === "gnome-terminal";
    }

    function isFileManagerApp(entry: var): bool {
        if (!entry)
            return false;
        if (root.hasCategory(entry, {
                    "FileManager": true
                }))
            return true;
        const bin = root.binName(String(entry.id || "")).replace(/\.desktop$/, "");
        return bin === "thunar" || bin === "nautilus" || bin === "dolphin" || bin === "nemo" || bin === "pcmanfm" || bin === "pcmanfm-qt";
    }

    function isMixerApp(entry: var): bool {
        if (!entry)
            return false;
        if (root.hasCategory(entry, {
                    "Mixer": true
                }))
            return true;
        const bin = root.binName(String(entry.id || "")).replace(/\.desktop$/, "");
        return bin === "pavucontrol" || bin === "pavucontrol-qt" || bin === "qpwgraph" || bin === "easyeffects" || bin === "helvum";
    }

    function isPlayerApp(entry: var): bool {
        if (!entry)
            return false;
        if (root.hasCategory(entry, {
                    "Mixer": true,
                    "FileManager": true,
                    "TextEditor": true,
                    "TerminalEmulator": true
                }))
            return false;
        if (root.hasCategory(entry, {
                    "Player": true,
                    "AudioVideo": true,
                    "Video": true,
                    "Audio": true
                }))
            return true;
        const bin = root.binName(String(entry.id || "")).replace(/\.desktop$/, "");
        return bin === "mpv" || bin === "vlc" || bin === "celluloid" || bin === "haruna" || bin === "totem";
    }

    function commandFromEntry(entry: var, fallback: string): var {
        try {
            const cmd = entry && entry.command ? entry.command : [];
            if (cmd && cmd.length)
                return Array.from(cmd);
        } catch (e) {}
        const bin = root.binName(fallback).replace(/\.desktop$/, "");
        return bin.length ? [bin] : [];
    }

    function lookupEntry(id: string): var {
        const raw = String(id || "").trim();
        if (!raw.length)
            return null;
        try {
            let e = DesktopEntries.byId(raw);
            if (e)
                return e;
            if (!raw.endsWith(".desktop"))
                e = DesktopEntries.byId(`${raw}.desktop`);
            return e || null;
        } catch (e) {
            return null;
        }
    }

    function idFromCommand(cmd: var, kind: string): string {
        if (root.isSystemCommand(cmd))
            return "system";
        if (kind === "explorer" && root.isFilesCommand(cmd))
            return root.filesAppId;
        const bin = root.binName(cmd[0]);
        const model = DesktopEntries.applications;
        const values = model && model.values ? model.values : [];
        for (let i = 0; i < values.length; ++i) {
            const e = values[i];
            if (e && !e.noDisplay && root.matchesBin(e, bin))
                return String(e.id || bin);
        }
        return bin;
    }

    function optionsFor(kind: string): var {
        const extras = [];
        if (kind === "explorer") {
            extras.push({
                text: root.filesAppName,
                value: root.filesAppId
            });
        }
        extras.push({
            text: qsTr("System default"),
            value: "system"
        });
        const seen = {
            system: true
        };
        if (kind === "explorer")
            seen[root.filesAppId] = true;
        const model = DesktopEntries.applications;
        const values = model && model.values ? model.values : [];
        const apps = [];
        for (let i = 0; i < values.length; ++i) {
            const e = values[i];
            if (!e || e.noDisplay || seen[e.id])
                continue;
            let ok = false;
            if (kind === "terminal")
                ok = root.isTerminalApp(e);
            else if (kind === "explorer")
                ok = root.isFileManagerApp(e);
            else if (kind === "audio")
                ok = root.isMixerApp(e);
            else if (kind === "playback")
                ok = root.isPlayerApp(e);
            if (!ok)
                continue;
            seen[e.id] = true;
            apps.push({
                text: String(e.name || e.id),
                value: String(e.id)
            });
        }
        apps.sort((a, b) => a.text.localeCompare(b.text));
        const current = kind === "terminal" ? root.terminalId : kind === "explorer" ? root.explorerId : kind === "audio" ? root.audioId : root.playbackId;
        if (current && !seen[current]) {
            const entry = root.lookupEntry(current);
            extras.push({
                text: entry && entry.name ? entry.name : current,
                value: current
            });
        }
        return extras.concat(apps);
    }

    function commandFor(kind: string, id: string): var {
        const value = String(id || "system").trim() || "system";
        if (value === "system")
            return [];
        if (kind === "explorer" && (value === root.filesAppId || value === root.filesDesktopFile))
            return ["qs", "-c", "donwaztok", "ipc", "call", "fileManager", "openPath"];
        const entry = root.lookupEntry(value);
        return root.commandFromEntry(entry, value);
    }

    function resolvedTerminal(): var {
        const cmd = Config.general.apps.terminal;
        if (cmd && cmd.length && !root.isSystemCommand(cmd))
            return Array.from(cmd);
        return ["xdg-terminal-exec"];
    }

    function setApp(kind: string, id: string): void {
        const value = String(id || "system").trim() || "system";
        const cmd = root.commandFor(kind, value);
        if (kind === "terminal")
            Config.general.apps.terminal = cmd;
        else if (kind === "explorer")
            Config.general.apps.explorer = cmd;
        else if (kind === "audio")
            Config.general.apps.audio = cmd;
        else if (kind === "playback")
            Config.general.apps.playback = cmd;
        Config.save();
        root.applyHandler(kind, value);
    }

    function applyHandler(kind: string, id: string): void {
        if (id === "system")
            return;
        if (kind === "terminal") {
            root.writeTerminalsList(id);
            return;
        }
        if (kind === "explorer") {
            root.ensureFilesDesktopEntry();
            const desk = (id === root.filesAppId || id === root.filesDesktopFile) ? root.filesDesktopFile : root.desktopName(id);
            root.applyMime(desk, root.filesMimes);
            return;
        }
        if (kind === "playback") {
            const entry = root.lookupEntry(id);
            const desk = root.desktopName(entry && entry.id ? entry.id : id);
            root.applyMime(desk, root.playbackMimes);
        }
    }

    function writeTerminalsList(id: string): void {
        const desk = root.desktopName(id);
        if (!desk.length)
            return;
        terminalsFile.path = root.terminalsListPath;
        terminalsFile.setText(`${desk}\n`);
    }

    function ensureFilesDesktopEntry(): void {
        const dir = `${Paths.home}/.local/share/applications`;
        Quickshell.execDetached(["mkdir", "-p", dir]);
        filesDesktopView.path = root.filesDesktopPath;
        filesDesktopView.setText(root.filesDesktopText());
        Quickshell.execDetached(["update-desktop-database", dir]);
    }

    function filesDesktopText(): string {
        const exec = "qs -c donwaztok ipc call fileManager openPath %f";
        let mimes = "";
        for (let i = 0; i < root.filesMimes.length; ++i)
            mimes += root.filesMimes[i] + ";";
        return "[Desktop Entry]\n" + "Type=Application\n" + "Name=Donwaztok Files\n" + "GenericName=File Manager\n" + "Comment=Browse files\n" + "Exec=" + exec + "\n" + "Icon=system-file-manager\n" + "Terminal=false\n" + "StartupNotify=false\n" + "Categories=Utility;FileManager;\n" + "MimeType=" + mimes + "\n";
    }

    property var mimeQueue: []

    function applyMime(desktop: string, mimes: var): void {
        const desk = root.desktopName(desktop);
        if (!desk.length || !mimes || !mimes.length)
            return;
        const parts = [];
        for (let i = 0; i < mimes.length; ++i)
            parts.push(`xdg-mime default '${desk}' '${mimes[i]}'`);
        const next = root.mimeQueue.slice();
        next.push(parts.join("; "));
        root.mimeQueue = next;
        root.pumpMime();
    }

    function pumpMime(): void {
        if (mimeProc.running)
            return;
        const q = root.mimeQueue;
        if (!q.length)
            return;
        const cmd = q[0];
        root.mimeQueue = q.slice(1);
        mimeProc.command = ["bash", "-lc", cmd];
        mimeProc.running = true;
    }

    function adopt(): void {
        root.ensureFilesDesktopEntry();
        const explorer = root.explorerId;
        if (explorer && explorer !== "system")
            root.applyHandler("explorer", explorer);
        const playback = root.playbackId;
        if (playback && playback !== "system")
            root.applyHandler("playback", playback);
        const terminal = root.terminalId;
        if (terminal && terminal !== "system")
            root.applyHandler("terminal", terminal);
    }

    Connections {
        target: DonwaztokConfigStore
        function onReadyChanged(): void {
            if (DonwaztokConfigStore.ready)
                root.adopt();
        }
    }

    Component.onCompleted: {
        if (DonwaztokConfigStore.ready)
            root.adopt();
        else
            root.ensureFilesDesktopEntry();
    }

    FileView {
        id: filesDesktopView
        printErrors: false
        atomicWrites: true
        preload: false
    }

    FileView {
        id: terminalsFile
        printErrors: false
        atomicWrites: true
        preload: false
    }

    Process {
        id: mimeProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Toaster.toast(qsTr("Could not set default app"), qsTr("xdg-mime exited with code %1").arg(exitCode), "error", Toast.Warning);
            root.pumpMime();
        }
    }
}
