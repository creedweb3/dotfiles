import QtQuick
import "../common"

// Mini player under the bar's music box, as wide as that box.
//   poster  a square: the cover fills it; swatches, title, seek line and controls sit over a
//           dark fade at the bottom
//   disc / vinyl  the disc on top, the text and controls under it, so nothing covers it
// Double click the cover: the quick panel's media tab.
Rectangle {
    id: root

    readonly property var player: Sys.player
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property bool poster: Prefs.mstyle === "poster"

    width: 248
    height: poster ? 248 : 254 + info.implicitHeight
    color: Theme.glass
    border.width: 1
    border.color: Theme.line
    clip: true

    Art {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.poster ? 1 : 14
        height: root.poster ? parent.height - 2 : width
    }

    MouseArea {
        anchors.fill: parent
        onDoubleClicked: Popup.open("panel", "media")
    }

    Rectangle {
        visible: root.poster
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
            visible: root.poster
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
            text: root.player ? root.player.trackTitle || "nothing playing" : "nothing playing"
            font.bold: true
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.player ? (root.player.trackTitle ? root.player.trackArtist : (root.player.identity || "player") + " is open") : ""
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
