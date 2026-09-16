pragma Singleton

import qs.components.misc
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQml

Singleton {
    id: root

    readonly property bool filterDuplicates: Config.shellOptions?.media?.filterDuplicatePlayers !== false

    readonly property bool hasActivePlasmaIntegration: Mpris.players.values.some(p => (p.dbusName || "").startsWith("org.mpris.MediaPlayer2.plasma-browser-integration"))

    readonly property list<MprisPlayer> list: Mpris.players.values.filter(p => root.isRealPlayer(p))

    readonly property MprisPlayer active: {
        const manual = props.manualActive;
        if (manual && root.list.indexOf(manual) >= 0)
            return manual;
        const preferred = root.list.find(p => root.getIdentity(p) === Config.services.defaultPlayer);
        if (preferred)
            return preferred;
        const playing = root.list.find(p => p.isPlaying);
        return playing ?? root.list[0] ?? null;
    }

    property alias manualActive: props.manualActive

    function isRealPlayer(player: var): bool {
        if (!player)
            return false;
        const name = player.dbusName || "";
        if (!root.filterDuplicates)
            return true;
        // Native browser buses duplicate plasma-browser-integration and often go stale
        if (root.hasActivePlasmaIntegration) {
            if (name.startsWith("org.mpris.MediaPlayer2.firefox"))
                return false;
            if (name.startsWith("org.mpris.MediaPlayer2.chromium"))
                return false;
        }
        // playerctld mirrors other buses
        if (name.startsWith("org.mpris.MediaPlayer2.playerctld"))
            return false;
        // Non-instance mpd bus
        if (name.endsWith(".mpd") && !name.endsWith("MediaPlayer2.mpd"))
            return false;
        return true;
    }

    function getIdentity(player: MprisPlayer): string {
        const alias = Config.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function canTrackPosition(player: var): bool {
        if (!player || !player.isPlaying)
            return false;
        if (!player.positionSupported)
            return false;
        // Drop players that left the live bus list (avoids Position Get on dead Firefox)
        if (Mpris.players.values.indexOf(player) < 0)
            return false;
        if (root.list.indexOf(player) < 0)
            return false;
        return true;
    }

    function refreshActivePosition(): void {
        const player = root.active;
        if (!root.canTrackPosition(player)) {
            if (props.manualActive && root.list.indexOf(props.manualActive) < 0)
                props.manualActive = null;
            return;
        }
        player.positionChanged();
    }

    Connections {
        target: Mpris.players

        function onValuesChanged(): void {
            if (props.manualActive && root.list.indexOf(props.manualActive) < 0)
                props.manualActive = null;
        }
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onDestruction: {
                if (props.manualActive === modelData)
                    props.manualActive = null;
            }
        }
    }

    Connections {
        target: active

        function onPostTrackChanged() {
            if (!Config.utilities.toasts.nowPlaying)
                return;
            if (active && active.trackArtist != "" && active.trackTitle != "")
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(active.trackArtist).arg(active.trackTitle), "music_note");
        }
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    CustomShortcut {
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            const p = root.active;
            if (p && p.canTogglePlaying)
                p.togglePlaying();
        }
    }

    CustomShortcut {
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const p = root.active;
            if (p && p.canGoPrevious)
                p.previous();
        }
    }

    CustomShortcut {
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const p = root.active;
            if (p && p.canGoNext)
                p.next();
        }
    }

    CustomShortcut {
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        target: "mpris"

        function pauseAll(): void {
            for (let i = 0; i < root.list.length; ++i) {
                const player = root.list[i];
                if (player.canPause)
                    player.pause();
            }
        }

        function playPause(): void {
            const p = root.active;
            if (p && p.canTogglePlaying)
                p.togglePlaying();
        }

        function previous(): void {
            const p = root.active;
            if (p && p.canGoPrevious)
                p.previous();
        }

        function next(): void {
            const p = root.active;
            if (p && p.canGoNext)
                p.next();
        }
    }
}
