pragma Singleton

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []
    property var cards: []
    property var monitors: []
    property var restoreProfiles: ({})
    property var disabledMonitors: []
    property bool stateLoaded: false
    property bool preferredApplied: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias beatTracker: beatTracker

    readonly property var outputEntries: {
        const _sinks = sinks;
        const _cards = cards;
        const entries = [];
        const seenCards = new Set();

        for (const node of _sinks) {
            const cardName = cardNameForNode(node);
            if (cardName)
                seenCards.add(cardName);

            entries.push({
                key: `node-${node.id}`,
                label: node.description || node.name || qsTr("Unknown"),
                enabled: true,
                selected: sink?.id === node.id,
                nodeId: node.id,
                cardName,
                sinkName: "",
                sinkId: -1,
                isMonitor: false,
                isSink: true
            });
        }

        for (const card of _cards) {
            if (card.enabled || !card.hasSink || seenCards.has(card.name))
                continue;

            entries.push({
                key: `card-${card.name}-sink`,
                label: card.description || card.name,
                enabled: false,
                selected: false,
                nodeId: -1,
                cardName: card.name,
                sinkName: "",
                sinkId: -1,
                isMonitor: false,
                isSink: true
            });
        }

        return entries;
    }

    readonly property var inputEntries: {
        const _sources = sources;
        const _cards = cards;
        const _monitors = monitors;
        const _disabledMonitors = disabledMonitors;
        const entries = [];
        const seenCards = new Set();

        for (const node of _sources) {
            const cardName = cardNameForNode(node);
            if (cardName)
                seenCards.add(cardName);

            entries.push({
                key: `node-${node.id}`,
                label: node.description || node.name || qsTr("Unknown"),
                enabled: true,
                selected: source?.id === node.id,
                nodeId: node.id,
                cardName,
                sinkName: "",
                sinkId: -1,
                isMonitor: false,
                isSink: false
            });
        }

        for (const card of _cards) {
            if (card.enabled || !card.hasSource || seenCards.has(card.name))
                continue;

            entries.push({
                key: `card-${card.name}-source`,
                label: card.description || card.name,
                enabled: false,
                selected: false,
                nodeId: -1,
                cardName: card.name,
                sinkName: "",
                sinkId: -1,
                isMonitor: false,
                isSink: false
            });
        }

        for (const mon of _monitors) {
            const enabled = !_disabledMonitors.includes(mon.sinkName);
            entries.push({
                key: `monitor-${mon.sinkName || mon.name}`,
                label: mon.description || qsTr("Monitor of %1").arg(mon.sinkName || mon.name),
                enabled,
                selected: false,
                nodeId: -1,
                cardName: "",
                sinkName: mon.sinkName || "",
                sinkId: mon.sinkId ?? -1,
                monitorName: mon.name || "",
                isMonitor: true,
                isSink: false
            });
        }

        return entries;
    }

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || Config.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || Config.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || Config.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || Config.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        return stream.applicationName || stream.description || stream.name || qsTr("Unknown Application");
    }

    function nodeById(nodeId: int): PwNode {
        for (const node of sinks) {
            if (node.id === nodeId)
                return node;
        }
        for (const node of sources) {
            if (node.id === nodeId)
                return node;
        }
        return null;
    }

    function cardNameForNode(node: PwNode): string {
        if (!node)
            return "";

        const props = node.properties || {};
        const deviceId = props["device.id"];
        if (deviceId !== undefined && deviceId !== null && deviceId !== "") {
            const match = cards.find(c => String(c.index) === String(deviceId));
            if (match)
                return match.name;
        }

        const nodeName = node.name || "";
        for (const card of cards) {
            const suffix = String(card.name || "").replace(/^alsa_card\./, "");
            if (suffix && nodeName.includes(suffix))
                return card.name;
        }

        return "";
    }

    function cardByName(cardName: string): var {
        return cards.find(c => c.name === cardName) ?? null;
    }

    function saveAudioState(): void {
        profileStorage.setText(JSON.stringify({
                profiles: restoreProfiles,
                disabledMonitors: disabledMonitors
            }));
    }

    function setCardProfile(cardName: string, profile: string, remember: bool): void {
        if (!cardName || !profile)
            return;

        if (remember && profile !== "off") {
            restoreProfiles = Object.assign({}, restoreProfiles, {
                [cardName]: profile
            });
            saveAudioState();
        }

        Quickshell.execDetached(["pactl", "set-card-profile", cardName, profile]);
        cardsRefreshTimer.restart();
    }

    function applyPreferredProfiles(): void {
        if (preferredApplied || !stateLoaded || cards.length === 0)
            return;

        preferredApplied = true;

        for (const card of cards) {
            if (!card.enabled)
                continue;

            const preferred = restoreProfiles[card.name];
            if (preferred && preferred !== "off" && preferred !== card.activeProfile)
                Quickshell.execDetached(["pactl", "set-card-profile", card.name, preferred]);
        }

        cardsRefreshTimer.restart();
    }

    function applyMonitorMute(sinkId: int, muted: bool): void {
        if (sinkId < 0)
            return;
        Quickshell.execDetached(["pw-cli", "s", String(sinkId), "Props", `{ monitorMute: ${muted ? "true" : "false"} }`]);
    }

    function setMonitorEnabled(sinkName: string, sinkId: int, enabled: bool): void {
        if (!sinkName)
            return;

        let next = disabledMonitors.slice();
        const idx = next.indexOf(sinkName);
        if (!enabled && idx < 0)
            next.push(sinkName);
        else if (enabled && idx >= 0)
            next.splice(idx, 1);

        disabledMonitors = next;
        saveAudioState();
        applyMonitorMute(sinkId, !enabled);
        cardsRefreshTimer.restart();
    }

    function setCardEnabled(cardName: string, enabled: bool): void {
        if (!cardName)
            return;

        const card = cardByName(cardName);
        if (!card)
            return;

        if (!enabled) {
            if (card.activeProfile && card.activeProfile !== "off") {
                restoreProfiles = Object.assign({}, restoreProfiles, {
                    [cardName]: card.activeProfile
                });
                saveAudioState();
            }
            Quickshell.execDetached(["pactl", "set-card-profile", cardName, "off"]);
        } else {
            const profile = restoreProfiles[cardName] || card.preferredProfile || card.preferredSinkProfile || card.preferredSourceProfile;
            if (!profile || profile === "off")
                return;
            setCardProfile(cardName, profile, false);
            return;
        }

        cardsRefreshTimer.restart();
    }

    function toggleEntryEnabled(entry: var): void {
        if (!entry)
            return;

        if (entry.isMonitor) {
            setMonitorEnabled(entry.sinkName, entry.sinkId, !entry.enabled);
            return;
        }

        if (!entry.cardName)
            return;

        setCardEnabled(entry.cardName, !entry.enabled);
    }

    function selectEntry(entry: var): void {
        if (!entry)
            return;

        if (entry.isMonitor) {
            if (!entry.enabled)
                setMonitorEnabled(entry.sinkName, entry.sinkId, true);
            if (entry.monitorName)
                Quickshell.execDetached(["pactl", "set-default-source", entry.monitorName]);
            return;
        }

        if (!entry.enabled) {
            if (entry.cardName)
                setCardEnabled(entry.cardName, true);
            return;
        }

        const node = nodeById(entry.nodeId);
        if (!node)
            return;

        if (entry.isSink)
            setAudioSink(node);
        else
            setAudioSource(node);
    }

    property bool scanning: false

    function syncDevices(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];

        for (const node of Pipewire.nodes.values) {
            if (!node.isStream) {
                if (node.isSink)
                    newSinks.push(node);
                else if (node.audio)
                    newSources.push(node);
            } else if (node.audio) {
                newStreams.push(node);
            }
        }

        root.sinks = newSinks;
        root.sources = newSources;
        root.streams = newStreams;
    }

    function refreshCards(): void {
        if (!cardsProc.running)
            cardsProc.running = true;
    }

    function rescanDevices(): void {
        if (scanning)
            return;

        scanning = true;
        syncDevices();
        refreshCards();
        scanTimer.restart();
    }

    Timer {
        id: scanTimer

        interval: 700
        onTriggered: {
            root.syncDevices();
            root.refreshCards();
            root.scanning = false;
        }
    }

    Timer {
        id: cardsRefreshTimer

        interval: 350
        onTriggered: root.refreshCards()
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && Config.utilities.toasts.audioOutputChanged)
            Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && Config.utilities.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
        syncDevices();
        refreshCards();
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.syncDevices();
            root.cardsRefreshTimer.restart();
        }
    }

    Process {
        id: cardsProc

        command: ["python3", Quickshell.shellPath("scripts/audio/list-cards.py")]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim() || "{}");
                    if (Array.isArray(parsed)) {
                        root.cards = parsed;
                        root.monitors = [];
                    } else {
                        root.cards = Array.isArray(parsed.cards) ? parsed.cards : [];
                        root.monitors = Array.isArray(parsed.monitors) ? parsed.monitors : [];
                    }

                    for (const mon of root.monitors) {
                        const shouldMute = root.disabledMonitors.includes(mon.sinkName);
                        if (shouldMute !== !!mon.muted && mon.sinkId >= 0)
                            root.applyMonitorMute(mon.sinkId, shouldMute);
                    }

                    root.applyPreferredProfiles();
                } catch (e) {
                    console.warn("[Audio] Failed to parse cards:", e);
                }
            }
        }
    }

    FileView {
        id: profileStorage

        path: `${Paths.state}/audio-cards.json`
        onLoaded: {
            try {
                const data = JSON.parse(text() || "{}");
                if (data && typeof data === "object" && (data.profiles || data.disabledMonitors)) {
                    root.restoreProfiles = data.profiles && typeof data.profiles === "object" ? data.profiles : {};
                    root.disabledMonitors = Array.isArray(data.disabledMonitors) ? data.disabledMonitors : [];
                } else {
                    root.restoreProfiles = data && typeof data === "object" ? data : {};
                    root.disabledMonitors = [];
                }
            } catch (e) {
                root.restoreProfiles = {};
                root.disabledMonitors = [];
            }
            root.stateLoaded = true;
            root.applyPreferredProfiles();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.restoreProfiles = {};
                root.disabledMonitors = [];
                setText(JSON.stringify({
                        profiles: {},
                        disabledMonitors: []
                    }));
            }
            root.stateLoaded = true;
            root.applyPreferredProfiles();
        }
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    BeatTracker {
        id: beatTracker
    }
}
