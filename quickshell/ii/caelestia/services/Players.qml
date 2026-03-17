pragma Singleton

import caelestia.components.misc
import caelestia.config
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQml

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === Config.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    function getIdentity(player: MprisPlayer): string {
        const alias = Config.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    Connections {
        target: active

        function onPostTrackChanged() {
            if (!Config.utilities.toasts.nowPlaying) {
                return;
            }
            if (active.trackArtist != "" && active.trackTitle != "") {
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(active.trackArtist).arg(active.trackTitle), "music_note");
            }
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
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    CustomShortcut {
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    CustomShortcut {
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    CustomShortcut {
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    // IpcHandler for "mpris" is registered in ii/services/MprisController.qml to avoid duplicate
}
