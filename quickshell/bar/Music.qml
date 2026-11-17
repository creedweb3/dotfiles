import QtQuick
import "../common"

// Now playing: three eq bars, then "title - artist". Fixed width, so the mini player under
// it never changes size; a title that does not fit scrolls in a loop.
// Click: mini player. Middle click: play / pause.
Box {
    id: root

    readonly property var player: Sys.player
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? [player.trackTitle, player.trackArtist].filter(s => s).join(" - ") : "nothing playing"

    implicitWidth: 248
    centered: false
    active: Popup.mode === "player"

    // eq: bars bounce while playing, rest low when paused
    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 13
        spacing: 2
        leftPadding: 1

        Repeater {
            model: 3
            Rectangle {
                id: eqBar
                required property int index
                width: 3
                height: 3
                anchors.bottom: parent.bottom
                color: root.active || root.hovered ? Theme.accent : Theme.fg

                SequentialAnimation on height {
                    running: root.playing
                    loops: Animation.Infinite
                    PauseAnimation { duration: eqBar.index * 200 }
                    NumberAnimation { from: 3; to: 13; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 13; to: 3; duration: 800; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) eqBar.height = 3
                }
            }
        }
    }

    Label {
        text: "|"
        color: Theme.muted
    }

    // marquee: two copies side by side slide left by one copy's width, then repeat
    Item {
        id: view
        width: root.width - x - root.padding - 1
        height: Theme.boxHeight
        clip: true

        readonly property bool loop: one.implicitWidth > width
        readonly property real gap: 2.5 * Theme.fontSize

        Row {
            id: strip
            anchors.verticalCenter: parent.verticalCenter
            spacing: view.gap

            Label {
                id: one
                text: root.title
                color: root.player ? Theme.fg : Theme.dim
            }
            Label {
                visible: view.loop
                text: root.title
            }

            NumberAnimation on x {
                running: view.loop
                loops: Animation.Infinite
                from: 0
                to: -(one.implicitWidth + view.gap)
                // about 30 px per second, as the demo's marquee
                duration: (one.implicitWidth + view.gap) * 33
                onRunningChanged: if (!running) strip.x = 0
            }
        }
    }

    onClicked: m => {
        if (m.button === Qt.MiddleButton) {
            if (player)
                player.togglePlaying();
            return;
        }
        Popup.playerRight = root.mapToItem(null, root.width, 0).x + Theme.barSide;
        Popup.toggle("player");
    }
}
