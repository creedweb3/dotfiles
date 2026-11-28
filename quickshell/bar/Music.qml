import QtQuick
import "../common"

// Now playing: three eq bars, then "title - artist". Fixed width while a player runs, so the
// mini player under it never changes size; a title that does not fit scrolls in a loop.
// With no player it shrinks to a music note, instead of a wide box saying "nothing playing".
// Click: mini player. Middle click: play / pause.
Box {
    id: root

    readonly property var player: Sys.player
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool idle: player === null || !player.trackTitle
    readonly property string title: player ? [player.trackTitle, player.trackArtist].filter(s => s).join(" - ") || player.identity : ""

    // room the bar has for it (Bar.qml); too little for a readable title: just the note
    property real maxWidth: 248
    readonly property bool cramped: maxWidth < 110
    implicitWidth: idle || cramped ? Theme.boxHeight + 10 : Math.min(248, maxWidth)
    padding: idle || cramped ? 0 : 10
    centered: idle || cramped

    Behavior on implicitWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    active: Popup.mode === "player"

    // marquee: the title twice side by side slides left by one copy's width, then repeats.
    // A scrolling title fades out at both ends. Text drawn through an effect layer goes soft, so
    // only the two narrow fading ends use one; the middle is ordinary, sharp text.
    Item {
        id: view
        visible: !root.idle && !root.cramped
        // the room left of the divider and the eq bars
        width: root.width - root.padding * 2 - 16 - divider.width - root.spacing * 2
        height: Theme.boxHeight
        clip: true

        readonly property real titleWidth: probe.implicitWidth
        readonly property bool loop: titleWidth > width
        readonly property real gap: Theme.snap(2.5 * Theme.fontSize)
        readonly property real fadeL: loop ? 16 : 0
        readonly property real fadeR: loop ? 20 : 0
        // scroll position, snapped to whole screen pixels so the text stays crisp
        property real offset: 0
        readonly property real sx: Math.round(offset * Theme.uiScale) / Theme.uiScale

        Label {
            id: probe
            visible: false
            text: root.title
        }

        NumberAnimation on offset {
            running: view.loop && view.visible
            loops: Animation.Infinite
            from: 0
            to: -(view.titleWidth + view.gap)
            // about 30 px per second, as the demo's marquee
            duration: (view.titleWidth + view.gap) * 33
            onRunningChanged: if (!running) view.offset = 0
        }

        // the sharp middle
        Item {
            x: view.fadeL
            width: view.width - view.fadeL - view.fadeR
            height: parent.height
            clip: true
            TitleStrip {
                text: root.title
                loop: view.loop
                gap: view.gap
                frame: view
                sx: view.sx
            }
        }

        // the two fading ends: no effect layer (a layer's resampling shimmers as text slides
        // through it). Each end is a row of 1-device-pixel slices, each showing the sharp text
        // clipped to that slice at a stepped opacity.
        Repeater {
            model: view.loop ? [0, 1] : []
            Item {
                id: edge
                required property int modelData
                readonly property bool isRight: modelData === 1
                readonly property real wantX: isRight ? view.width - view.fadeR : 0
                // on whole device pixels, so every slice is exactly one screen pixel
                x: {
                    const s = Theme.uiScale
                    const ox = view.mapToItem(null, 0, 0).x + view.sx * 0
                    return Math.round((ox + wantX) * s) / s - ox
                }
                readonly property int slices: Math.round((isRight ? view.fadeR : view.fadeL) * Theme.uiScale)
                width: slices / Theme.uiScale
                height: view.height
                Repeater {
                    model: edge.slices
                    Item {
                        id: slice
                        required property int index
                        x: index / Theme.uiScale
                        width: 1 / Theme.uiScale
                        height: edge.height
                        clip: true
                        // fully clear at the outer edge, nearly opaque next to the middle
                        opacity: {
                            const t = (index + 0.5) / edge.slices
                            return edge.isRight ? 1 - t : t
                        }
                        TitleStrip {
                            text: root.title
                            loop: view.loop
                            gap: view.gap
                            frame: view
                            sx: view.sx
                        }
                    }
                }
            }
        }
    }

    // a thin line between the title and the eq bars
    Rectangle {
        id: divider
        visible: !root.idle && !root.cramped
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 12
        color: Theme.muted
    }

    // eq, at the right end (alone, centred, when nothing plays or the box is cramped): the bars
    // always hop: full height while playing, a smaller, slower hop when paused or idle
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
                color: root.active || root.hovered ? Theme.accent : root.playing ? Theme.fg : Theme.dim
                readonly property real peak: root.playing ? 13 : 8
                readonly property int half: root.playing ? 800 : 1100

                SequentialAnimation on height {
                    running: true
                    loops: Animation.Infinite
                    PauseAnimation { duration: eqBar.index * 200 }
                    NumberAnimation { from: 3; to: eqBar.peak; duration: eqBar.half; easing.type: Easing.InOutSine }
                    NumberAnimation { from: eqBar.peak; to: 3; duration: eqBar.half; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    onClicked: m => {
        if (m.button === Qt.MiddleButton) {
            if (player)
                player.togglePlaying();
            return;
        }
        // the mini player (248 wide) opens under this box, its left edge in line with the box's
        Popup.playerRight = root.mapToItem(null, 0, 0).x + Theme.barSide + 248;
        Popup.toggle("player");
    }
}
