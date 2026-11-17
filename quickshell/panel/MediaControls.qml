import QtQuick
import Quickshell.Services.Mpris
import "../common"

// shuffle · previous · play/pause · next · repeat for the current MPRIS player.
Row {
    id: root

    readonly property var player: Sys.player

    spacing: 14
    enabled: player !== null

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.shuffle
        size: 15
        visible: root.player !== null && root.player.shuffleSupported
        toggled: root.player !== null && root.player.shuffle
        onClicked: root.player.shuffle = !root.player.shuffle
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.prev
        enabled: root.player !== null && root.player.canGoPrevious
        onClicked: root.player.previous()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.player && root.player.isPlaying ? Icons.pause : Icons.play
        size: 24
        enabled: root.player !== null && root.player.canTogglePlaying
        onClicked: root.player.togglePlaying()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.next
        enabled: root.player !== null && root.player.canGoNext
        onClicked: root.player.next()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.repeat
        size: 15
        visible: root.player !== null && root.player.loopSupported
        toggled: root.player !== null && root.player.loopState !== MprisLoopState.None
        onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None
    }
}
