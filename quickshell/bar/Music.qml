import QtQuick
import QtQuick.Effects
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

    Icon {
        visible: root.idle || root.cramped
        anchors.verticalCenter: parent.verticalCenter
        path: Icons.music
        size: 14
        color: root.hovered ? Theme.accent : Theme.dim
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
        readonly property real gap: 2.5 * Theme.fontSize
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
                sx: view.sx - view.fadeL
            }
        }

        // the two fading ends
        Repeater {
            model: view.loop ? [0, 1] : []
            Item {
                id: edge
                required property int modelData
                readonly property bool isRight: modelData === 1
                x: isRight ? view.width - view.fadeR : 0
                width: isRight ? view.fadeR : view.fadeL
                height: view.height
                clip: true
                layer.enabled: true
                layer.textureSize: Qt.size(Math.ceil(width * Theme.uiScale * 2), Math.ceil(height * Theme.uiScale * 2))
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: edgeMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                TitleStrip {
                    text: root.title
                    loop: view.loop
                    gap: view.gap
                    sx: view.sx - edge.x
                }
                Item {
                    id: edgeMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: edge.isRight ? "black" : "transparent" }
                            GradientStop { position: 1; color: edge.isRight ? "transparent" : "black" }
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

    // eq, at the right end: bars bounce while playing, rest low when paused
    Row {
        visible: !root.idle && !root.cramped
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
