import QtQuick
import "../common"

// One workspace; the active one is solid accent. How the others look is Settings > Bar >
// open marker (Prefs.marker), as the demo:
//   frame       all bright, ones with windows outlined in the accent
//   dim         empty ones faded, ones with windows bright
//   dimframe    empty ones faded, ones with windows bright and outlined (default)
//   fill        all bright, ones with windows filled with a 30% accent tint
Box {
    id: root

    required property int wsId
    required property bool occupied
    required property bool current

    implicitWidth: Math.max(34, label.implicitWidth + padding * 2)
    readonly property bool framed: occupied && (Prefs.marker === "frame" || Prefs.marker === "dimframe")
    readonly property bool bright: occupied || Prefs.marker === "frame" || Prefs.marker === "fill"

    color: current ? Theme.accent : occupied && Prefs.marker === "fill" ? Theme.alpha(Theme.mix(Theme.accent, Theme.panel, 0.3), 0.84) : Theme.boxFill
    border.color: current || framed || hovered ? Theme.accent : Theme.line

    Label {
        id: label
        text: String(root.wsId % 10)
        color: root.current ? Theme.bg : root.bright ? Theme.fg : Theme.alpha(Theme.fg, 0.45)
    }

    onClicked: Sys.goWorkspace(wsId)
}
