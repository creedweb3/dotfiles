import QtQuick
import "../common"

// Quick panel, media tab: the current player with cover, seek bar and controls, the players to
// pick from, then the output device and its volume. The layout follows Settings > Panels >
// media player (Prefs.mstyle), as in the demo:
//   poster  the cover beside "on <player>", title, artist and the controls
//   vinyl   a larger record with its tonearm, title, artist and the controls beside it
//   disc    the cover beside the title, the controls centred under the seek bar
// The demo's "up next" line is left out: MPRIS players do not share their queue.
Column {
    id: root

    readonly property var player: Sys.player
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property string style: Prefs.mstyle

    spacing: 10

    Card {
        width: parent.width
        spacing: 10

        Row {
            width: parent.width
            spacing: 14

            Art {
                id: art
                width: root.style === "vinyl" ? 170 : 150
                height: width
            }

            Column {
                width: parent.width - art.width - parent.spacing
                height: art.height
                spacing: 4

                Label {
                    visible: root.style === "poster" && root.player !== null
                    width: parent.width
                    text: root.player ? "on " + root.player.identity : ""
                    color: Theme.accent
                    font.pixelSize: Theme.smallSize
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: root.player ? root.player.trackTitle || "unknown track" : "nothing playing"
                    font.pixelSize: root.style === "vinyl" ? 18 : 15
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: root.player ? root.player.trackArtist : "start music in any player"
                    color: Theme.dim
                    elide: Text.ElideRight
                }
                Label {
                    visible: root.style === "disc"
                    width: parent.width
                    text: root.player ? root.player.identity : ""
                    color: Theme.accent
                    font.pixelSize: Theme.smallSize
                    elide: Text.ElideRight
                }
                // poster and vinyl: the controls sit at the bottom of this column
                Item {
                    visible: root.style !== "disc"
                    width: parent.width
                    height: Math.max(0, art.height - y - besideControls.implicitHeight)
                }
                MediaControls {
                    id: besideControls
                    visible: root.style !== "disc"
                }
            }
        }

        Column {
            width: parent.width
            visible: root.length > 0
            spacing: 2

            Slider {
                width: parent.width
                from: 0
                to: root.length
                step: 5
                value: root.player ? root.player.position : 0
                enabled: root.player !== null && root.player.canSeek
                onMoved: v => root.player.position = v
            }
            Item {
                width: parent.width
                height: 16
                Label {
                    text: Sys.fmtTime(root.player ? root.player.position : 0)
                    color: Theme.dim
                    font.pixelSize: Theme.smallSize
                }
                Label {
                    anchors.right: parent.right
                    text: Sys.fmtTime(root.length)
                    color: Theme.dim
                    font.pixelSize: Theme.smallSize
                }
            }
        }

        MediaControls {
            visible: root.style === "disc"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // source: every running player; the one picked stays the panel's player while it runs
    Card {
        title: "source"
        width: parent.width
        visible: Sys.players.length > 0

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: Sys.players

                Rectangle {
                    required property var modelData
                    readonly property bool on: modelData === root.player
                    width: chip.implicitWidth + 20
                    height: 26
                    color: on ? Theme.accent : "transparent"
                    border.width: 1
                    border.color: on ? Theme.accent : chipMouse.containsMouse ? Theme.fg : Theme.muted

                    Label {
                        id: chip
                        anchors.centerIn: parent
                        text: parent.modelData.identity || parent.modelData.dbusName
                        color: parent.on ? Theme.bg : Theme.fg
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sys.choosePlayer(parent.modelData)
                    }
                }
            }
        }
    }

    Card {
        title: "output · " + Sys.sinkName
        width: parent.width

        RangeRow {
            width: parent.width
            label: "volume"
            value: Sys.volume
            valueText: Sys.muted ? "muted" : Sys.volume + "%"
            onMoved: v => Sys.setVolume(Math.round(v))
        }
        RangeRow {
            width: parent.width
            label: "microphone"
            value: Sys.micVolume
            valueText: Sys.micMuted ? "muted" : Sys.micVolume + "%"
            onMoved: v => {
                if (Sys.hasSource) {
                    Sys.source.audio.muted = false;
                    Sys.source.audio.volume = v / 100;
                }
            }
        }
    }
}
