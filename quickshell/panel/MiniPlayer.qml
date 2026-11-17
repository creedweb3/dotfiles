import QtQuick
import "../common"

// Mini player under the bar's music box: a square as wide as that box. The cover fills it;
// the palette's swatches, title, seek line and controls sit over a dark fade at the bottom.
// Double click the cover: the quick panel's media tab.
Rectangle {
    id: root

    readonly property var player: Sys.player
    readonly property real length: player && player.lengthSupported ? player.length : 0

    width: 248
    height: 248
    color: Theme.glass
    border.width: 1
    border.color: Theme.line
    clip: true

    Art {
        anchors.fill: parent
        anchors.margins: 1
    }

    MouseArea {
        anchors.fill: parent
        onDoubleClicked: Popup.open("panel", "media")
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: info.implicitHeight + 40
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.45; color: Theme.alpha(Theme.bg, 0.75) }
            GradientStop { position: 1; color: Theme.alpha(Theme.bg, 0.92) }
        }
    }

    Column {
        id: info
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: 4

        // the palette, as a strip of swatches (the demo's poster look)
        Row {
            bottomPadding: 2
            spacing: 3
            Repeater {
                model: [Theme.bg, Theme.muted, Theme.dim, Theme.accent, Theme.accent2, Theme.fg]
                Rectangle {
                    required property var modelData
                    width: 14
                    height: 6
                    color: modelData
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.15)
                }
            }
        }
        Label {
            width: parent.width
            text: root.player ? root.player.trackTitle || "unknown track" : "nothing playing"
            font.bold: true
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.player ? root.player.trackArtist : ""
            color: Theme.dim
            elide: Text.ElideRight
        }
        Slider {
            width: parent.width
            visible: root.length > 0
            from: 0
            to: root.length
            value: root.player ? root.player.position : 0
            enabled: root.player !== null && root.player.canSeek
            onMoved: v => root.player.position = v
        }
        MediaControls {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
        }
    }
}
