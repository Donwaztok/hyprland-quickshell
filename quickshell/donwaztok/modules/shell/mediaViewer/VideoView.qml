import qs.components
import qs.services.shell
import qs.config
import QtMultimedia
import QtQuick

Item {
    id: root

    signal doubleTapped

    property alias source: player.source
    property alias position: player.position
    readonly property alias duration: player.duration
    readonly property alias seekable: player.seekable
    readonly property alias muted: audio.muted
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property string errorText: player.error === MediaPlayer.NoError ? "" : player.errorString

    function toggle(): void {
        if (root.playing)
            player.pause();
        else
            player.play();
    }

    function toggleMute(): void {
        audio.muted = !audio.muted;
    }

    function seek(ms: real): void {
        player.position = Math.max(0, Math.min(player.duration, player.position + ms));
    }

    onSourceChanged: player.play()

    MediaPlayer {
        id: player
        videoOutput: output
        audioOutput: AudioOutput {
            id: audio
        }
    }

    VideoOutput {
        id: output
        anchors.fill: parent
    }

    TapHandler {
        // Each tap toggles, so a double click pauses and resumes: net unchanged, then fullscreen.
        onTapped: root.toggle()
        onDoubleTapped: root.doubleTapped()
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: !player.hasVideo && player.mediaStatus !== MediaPlayer.LoadingMedia && !root.errorText.length
        text: "music_note"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.extraLarge * 2
    }
}
