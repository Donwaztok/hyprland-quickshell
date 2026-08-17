pragma Singleton

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    property string previousSourceName: ""
    property var recentOutputs: []
    property string pendingOutputName: ""
    property string pendingDefaultSource: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []
    property var cards: []
    property var monitors: []
    property var restoreProfiles: ({})
    property var disabledMonitors: []
    property var disabledCards: []
    property var appliedMonitorMutes: ({})
    property bool stateLoaded: false
    property bool preferredApplied: false
    property bool profileSwitching: false
    property string cardsFingerprint: ""

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
                nodeName: node.name || "",
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
                nodeName: "",
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
                nodeName: node.name || "",
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
                nodeName: "",
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
        if (!newSink)
            return;

        Pipewire.preferredDefaultAudioSink = newSink;
        Quickshell.execDetached(["wpctl", "set-default", String(newSink.id)]);
        if (newSink.name) {
            Quickshell.execDetached(["pactl", "set-default-sink", newSink.name]);
            Quickshell.execDetached(["pactl", "set-sink-mute", newSink.name, "0"]);
        }
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
        if (newSource?.name)
            Quickshell.execDetached(["pactl", "set-default-source", newSource.name]);
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
                disabledMonitors: disabledMonitors,
                disabledCards: disabledCards,
                recentOutputs: recentOutputs
            }));
    }

    function rememberRecentOutput(sinkName: string): void {
        if (!sinkName || recentOutputs[0] === sinkName)
            return;

        const next = [sinkName];
        if (recentOutputs[0])
            next.push(recentOutputs[0]);
        recentOutputs = next;
        saveAudioState();
    }

    function sinkByName(sinkName: string): PwNode {
        for (const node of sinks) {
            if (node?.name === sinkName)
                return node;
        }
        return null;
    }

    function cardForSinkName(sinkName: string): var {
        for (const card of cards) {
            const suffix = String(card.name || "").replace(/^alsa_card\./, "");
            if (suffix && sinkName.includes(suffix))
                return card;
        }
        return null;
    }

    function applyOutputByName(sinkName: string): void {
        if (!sinkName)
            return;

        const node = sinkByName(sinkName);
        if (node) {
            pendingOutputName = "";
            if (node.audio)
                node.audio.muted = false;
            setAudioSink(node);
            return;
        }

        const card = cardForSinkName(sinkName);
        if (!card || pendingOutputName === sinkName) {
            pendingOutputName = "";
            return;
        }

        pendingOutputName = sinkName;
        if (!card.enabled)
            setCardEnabled(card.name, true);
        else
            beginProfileSwitch();
    }

    function togglePreviousOutput(): void {
        const targetName = recentOutputs.length > 1 ? recentOutputs[1] : "";
        if (!targetName)
            return;
        applyOutputByName(targetName);
    }

    function isRestorableProfile(profile: string): bool {
        if (!profile || profile === "off" || profile === "pro-audio")
            return false;
        if (profile.startsWith("input:") && !profile.includes("output:"))
            return false;
        return true;
    }

    function profileIncludesSink(card: var, profileName: string): bool {
        const match = (card?.profiles || []).find(p => p.name === profileName);
        return !!match && match.sinks > 0;
    }

    function profileIncludesSource(card: var, profileName: string): bool {
        const match = (card?.profiles || []).find(p => p.name === profileName);
        return !!match && match.sources > 0;
    }

    function duplexProfileForCard(card: var): string {
        if (!card?.hasSink || !card?.hasSource)
            return "";

        if (card.preferredDuplexProfile)
            return card.preferredDuplexProfile;

        let best = "";
        let bestPri = -1;
        for (const profile of (card.profiles || [])) {
            if (profile.sinks <= 0 || profile.sources <= 0 || profile.available === false)
                continue;
            if (profile.priority > bestPri) {
                bestPri = profile.priority;
                best = profile.name;
            }
        }
        return best;
    }

    function resolveStoredProfile(card: var): string {
        let profile = restoreProfiles[card.name] || "";
        if (!isRestorableProfile(profile))
            profile = "";

        const duplex = duplexProfileForCard(card);
        if (!duplex)
            return profile || card.preferredProfile || card.preferredSinkProfile || card.preferredSourceProfile || "";

        if (!profile)
            return duplex;

        if (profileIncludesSink(card, profile) && profileIncludesSource(card, profile))
            return profile;

        return duplex;
    }

    function ensureDuplexForCard(cardName: string, nodeName: string, isSink: bool): bool {
        const card = cardByName(cardName);
        if (!card)
            return false;

        const duplex = duplexProfileForCard(card);
        if (!duplex || card.activeProfile === duplex)
            return false;

        const active = card.activeProfile;
        if (profileIncludesSink(card, active) && profileIncludesSource(card, active))
            return false;

        if (isSink)
            pendingOutputName = nodeName || pendingOutputName;
        else
            pendingDefaultSource = nodeName || pendingDefaultSource;

        setCardProfile(cardName, duplex, true);
        return true;
    }

    function sourceByName(sourceName: string): PwNode {
        for (const node of sources) {
            if (node?.name === sourceName)
                return node;
        }
        return null;
    }

    function cardForSourceName(sourceName: string): var {
        for (const card of cards) {
            const suffix = String(card.name || "").replace(/^alsa_card\./, "");
            if (suffix && sourceName.includes(suffix))
                return card;
        }
        return null;
    }

    function applySourceByName(sourceName: string): void {
        if (!sourceName)
            return;

        const node = sourceByName(sourceName);
        if (node) {
            pendingDefaultSource = "";
            if (node.audio)
                node.audio.muted = false;
            setAudioSource(node);
            return;
        }

        const card = cardForSourceName(sourceName);
        if (!card || pendingDefaultSource === sourceName) {
            pendingDefaultSource = "";
            return;
        }

        pendingDefaultSource = sourceName;
        if (!card.enabled)
            setCardEnabled(card.name, true);
        else
            beginProfileSwitch();
    }

    function beginProfileSwitch(): void {
        profileSwitching = true;
        profileSettleTimer.restart();
    }

    function applyCardProfile(cardName: string, profile: string): void {
        if (!cardName || !profile)
            return;

        const active = cardByName(cardName)?.activeProfile || "";
        if (active === profile)
            return;

        if (active === "off" && profile !== "off" && profile !== "pro-audio") {
            Quickshell.execDetached(["bash", "-lc", `pactl set-card-profile '${cardName}' pro-audio && sleep 0.45 && pactl set-card-profile '${cardName}' '${profile}'`]);
            return;
        }

        Quickshell.execDetached(["pactl", "set-card-profile", cardName, profile]);
    }

    function setCardProfile(cardName: string, profile: string, remember: bool): void {
        if (!cardName || !profile)
            return;

        if (remember && isRestorableProfile(profile)) {
            restoreProfiles = Object.assign({}, restoreProfiles, {
                [cardName]: profile
            });
            saveAudioState();
        }

        const nextCards = [];
        for (const card of cards) {
            if (card.name !== cardName) {
                nextCards.push(card);
                continue;
            }
            const match = (card.profiles || []).find(p => p.name === profile);
            nextCards.push(Object.assign({}, card, {
                activeProfile: profile,
                activeProfileLabel: match?.label || profile,
                enabled: profile !== "off"
            }));
        }
        cards = nextCards;
        cardsFingerprint = "";

        applyCardProfile(cardName, profile);
        beginProfileSwitch();
    }

    function rememberActiveProfiles(): void {
        if (profileSwitching || !stateLoaded)
            return;

        let changed = false;
        const next = Object.assign({}, restoreProfiles);
        for (const card of cards) {
            if (!card?.name || !card.enabled || disabledCards.includes(card.name))
                continue;
            if (!isRestorableProfile(card.activeProfile) || next[card.name] === card.activeProfile)
                continue;

            let active = card.activeProfile;
            const duplex = duplexProfileForCard(card);
            if (duplex && !(profileIncludesSink(card, active) && profileIncludesSource(card, active)))
                active = duplex;

            if (next[card.name] === active)
                continue;
            next[card.name] = active;
            changed = true;
        }
        if (!changed)
            return;

        restoreProfiles = next;
        saveAudioState();
    }

    function syncDisabledCardsConfig(): void {
        const names = (disabledCards || []).filter(name => typeof name === "string" && name);
        let body = "# Generated by donwaztok from panel-disabled audio cards.\n";
        if (!names.length) {
            body += "monitor.alsa.rules = []\n";
        } else {
            const matches = names.map(name => `      { device.name = "${name.replace(/"/g, "")}" }`).join("\n");
            body += `monitor.alsa.rules = [\n  {\n    matches = [\n${matches}\n    ]\n    actions = {\n      update-props = {\n        device.profile = "off"\n      }\n    }\n  }\n]\n`;
        }
        disabledCardsConfig.setText(body);
    }

    function enforceDisabledCards(): bool {
        if (!stateLoaded || cards.length === 0)
            return false;

        let switched = false;
        for (const card of cards) {
            if (!card?.name || !disabledCards.includes(card.name))
                continue;
            if (!card.enabled && card.activeProfile === "off")
                continue;
            applyCardProfile(card.name, "off");
            switched = true;
        }
        return switched;
    }

    function applyPreferredProfiles(): void {
        if (!stateLoaded || cards.length === 0)
            return;

        let switched = enforceDisabledCards();
        for (const card of cards) {
            if (!card?.name || disabledCards.includes(card.name))
                continue;

            let preferred = resolveStoredProfile(card);
            if (!isRestorableProfile(preferred)) {
                if (!card.enabled)
                    continue;
                if (card.activeProfile === "pro-audio")
                    preferred = card.preferredProfile || card.preferredSinkProfile || card.preferredSourceProfile;
            }

            if (!isRestorableProfile(preferred) || preferred === card.activeProfile)
                continue;

            if (!card.enabled && preferredApplied)
                continue;

            applyCardProfile(card.name, preferred);
            switched = true;
        }

        const firstApply = !preferredApplied;
        preferredApplied = true;
        if (switched)
            beginProfileSwitch();
        else if (firstApply)
            cardsRefreshTimer.restart();
    }

    function applyMonitorMute(sinkId: int, muted: bool): void {
        if (sinkId < 0)
            return;
        Quickshell.execDetached(["pw-cli", "s", String(sinkId), "Props", `{ monitorMute: ${muted ? "true" : "false"} }`]);
    }

    function syncMonitorMutes(): void {
        const next = Object.assign({}, appliedMonitorMutes);

        for (const mon of monitors) {
            if (!mon?.sinkName || mon.sinkId < 0)
                continue;

            const shouldMute = disabledMonitors.includes(mon.sinkName);
            if (next[mon.sinkName] === shouldMute)
                continue;

            applyMonitorMute(mon.sinkId, shouldMute);
            next[mon.sinkName] = shouldMute;
        }

        appliedMonitorMutes = next;
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
        appliedMonitorMutes = Object.assign({}, appliedMonitorMutes, {
            [sinkName]: !enabled
        });
        saveAudioState();
        applyMonitorMute(sinkId, !enabled);
    }

    function setCardEnabled(cardName: string, enabled: bool): void {
        if (!cardName)
            return;

        const card = cardByName(cardName);
        if (!card)
            return;

        if (!enabled) {
            if (isRestorableProfile(card.activeProfile)) {
                restoreProfiles = Object.assign({}, restoreProfiles, {
                    [cardName]: card.activeProfile
                });
            }
            if (!disabledCards.includes(cardName)) {
                disabledCards = disabledCards.concat([cardName]);
            }
            saveAudioState();
            syncDisabledCardsConfig();
            applyCardProfile(cardName, "off");
            beginProfileSwitch();
            return;
        }

        if (disabledCards.includes(cardName)) {
            disabledCards = disabledCards.filter(name => name !== cardName);
            saveAudioState();
            syncDisabledCardsConfig();
        }

        const profile = resolveStoredProfile(card);
        if (!isRestorableProfile(profile))
            return;
        setCardProfile(cardName, profile, false);
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
        if (entry.isSink) {
            if (entry.cardName && ensureDuplexForCard(entry.cardName, entry.nodeName, true))
                return;
            if (node)
                setAudioSink(node);
            else if (entry.nodeName)
                applyOutputByName(entry.nodeName);
            return;
        }

        if (entry.cardName && ensureDuplexForCard(entry.cardName, entry.nodeName, false))
            return;

        if (node)
            setAudioSource(node);
        else if (entry.nodeName)
            applySourceByName(entry.nodeName);
    }

    property bool scanning: false

    function nodeKey(nodes: var): string {
        let key = "";
        for (let i = 0; i < nodes.length; i++)
            key += `${nodes[i].id},`;
        return key;
    }

    function syncDevices(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];

        try {
            for (const node of Pipewire.nodes.values) {
                if (!node)
                    continue;
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }
        } catch (e) {
            console.warn("[Audio] syncDevices:", e);
            return;
        }

        let sinksChanged = true;
        let sourcesChanged = true;
        let streamsChanged = true;
        try {
            sinksChanged = nodeKey(newSinks) !== nodeKey(root.sinks);
            sourcesChanged = nodeKey(newSources) !== nodeKey(root.sources);
            streamsChanged = nodeKey(newStreams) !== nodeKey(root.streams);
        } catch (e) {
        }

        if (sinksChanged)
            root.sinks = newSinks;
        if (sourcesChanged)
            root.sources = newSources;
        if (streamsChanged)
            root.streams = newStreams;

        if ((sinksChanged || sourcesChanged) && !root.profileSwitching && cardsRefreshTimer)
            cardsRefreshTimer.restart();
    }

    function refreshCards(): void {
        if (cardsProc.running) {
            cardsProc.running = false;
            cardsWatchdog.stop();
        }
        cardsProc.running = true;
        cardsWatchdog.restart();
    }

    function rescanDevices(): void {
        if (scanning)
            return;

        scanning = true;
        preferredApplied = false;
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

    Timer {
        id: cardsWatchdog

        interval: 12000
        onTriggered: {
            if (cardsProc.running)
                cardsProc.running = false;
        }
    }

    Timer {
        id: profileSettleTimer

        interval: 1200
        onTriggered: {
            root.profileSwitching = false;
            root.syncDevices();
            root.refreshCards();
            if (root.pendingOutputName)
                root.applyOutputByName(root.pendingOutputName);
            if (root.pendingDefaultSource)
                root.applySourceByName(root.pendingDefaultSource);
        }
    }

    onSinkChanged: {
        if (!stateLoaded || !sink?.ready)
            return;
        rememberRecentOutput(sink.name || "");
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
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
        syncDevices();
        refreshCards();
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.syncDevices();
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
                cardsWatchdog.stop();
                try {
                    const parsed = JSON.parse(text.trim() || "{}");
                    const nextCards = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.cards) ? parsed.cards : []);
                    const nextMonitors = Array.isArray(parsed) ? [] : (Array.isArray(parsed.monitors) ? parsed.monitors : []);
                    const fingerprint = JSON.stringify({
                        cards: nextCards,
                        monitors: nextMonitors
                    });

                    if (fingerprint !== root.cardsFingerprint) {
                        root.cardsFingerprint = fingerprint;
                        root.cards = nextCards;
                        root.monitors = nextMonitors;
                    }

                    root.syncMonitorMutes();
                    root.rememberActiveProfiles();
                    root.applyPreferredProfiles();
                } catch (e) {
                    console.warn("[Audio] Failed to parse cards:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err)
                    console.warn("[Audio] list-cards:", err);
            }
        }
    }

    FileView {
        id: disabledCardsConfig

        path: `${Paths.home}/.config/wireplumber/wireplumber.conf.d/53-donwaztok-disabled-cards.conf`
    }

    FileView {
        id: profileStorage

        path: `${Paths.state}/audio-cards.json`
        onLoaded: {
            try {
                const data = JSON.parse(text() || "{}");
                let profiles = {};
                if (data && typeof data === "object" && (data.profiles || data.disabledMonitors))
                    profiles = data.profiles && typeof data.profiles === "object" ? Object.assign({}, data.profiles) : {};
                else if (data && typeof data === "object")
                    profiles = Object.assign({}, data);

                let sanitized = false;
                for (const name of Object.keys(profiles)) {
                    if (!root.isRestorableProfile(profiles[name])) {
                        delete profiles[name];
                        sanitized = true;
                    }
                }

                root.restoreProfiles = profiles;
                root.disabledMonitors = data && typeof data === "object" && Array.isArray(data.disabledMonitors) ? data.disabledMonitors : [];
                root.disabledCards = data && typeof data === "object" && Array.isArray(data.disabledCards) ? data.disabledCards : [];
                root.recentOutputs = data && typeof data === "object" && Array.isArray(data.recentOutputs) ? data.recentOutputs.filter(name => typeof name === "string" && name) : [];
                root.syncDisabledCardsConfig();
                if (sanitized)
                    root.saveAudioState();
            } catch (e) {
                root.restoreProfiles = {};
                root.disabledMonitors = [];
                root.disabledCards = [];
                root.recentOutputs = [];
                root.syncDisabledCardsConfig();
            }
            root.stateLoaded = true;
            if (root.sink?.name)
                root.rememberRecentOutput(root.sink.name);
            root.applyPreferredProfiles();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.restoreProfiles = {};
                root.disabledMonitors = [];
                root.disabledCards = [];
                root.recentOutputs = [];
                root.syncDisabledCardsConfig();
                setText(JSON.stringify({
                        profiles: {},
                        disabledMonitors: [],
                        disabledCards: [],
                        recentOutputs: []
                    }));
            }
            root.stateLoaded = true;
            if (root.sink?.name)
                root.rememberRecentOutput(root.sink.name);
            root.applyPreferredProfiles();
        }
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    IpcHandler {
        target: "audio"

        function togglePreviousOutput(): void {
            root.togglePreviousOutput();
        }
    }

    BeatTracker {
        id: beatTracker
    }
}
