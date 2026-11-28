pragma Singleton
import QtQuick
import Quickshell

// Which bar pop-up is open. One at a time, as in the demo.
//   mode  the quick panel or the mini player (panel/PanelHost.qml)
//   side  the notification centre or a small sound / Bluetooth / Wi-Fi pop-up (panel/SideHost.qml)
// Opening one kind closes the other.
Singleton {
    id: root

    property string mode: ""         // "", "panel" (quick panel) or "player" (mini player)
    property string tab: "dash"      // quick panel tab: dash, media, system
    property real playerRight: 0     // mini player: right edge of the bar's music box, in screen pixels

    property string side: ""         // "", "nc", "sound", "bt" or "wifi"
    property real sideX: 0           // small pop-ups: centre of the bar icon they belong to, in screen pixels
    property string sideScreen: ""   // name of the screen whose bar opened it
    // still on screen (open, or playing its closing animation): the bar stays above them till then
    property bool panelShown: false
    property bool sideShown: false
    // a pop-up window moved to another screen and was mapped again, on top of the bars
    signal hostMoved()

    onModeChanged: if (mode !== "") side = ""
    onSideChanged: if (side !== "") mode = ""

    function toggle(m) {
        mode = mode === m ? "" : m;
    }

    function open(m, t) {
        if (t)
            tab = t;
        mode = m;
    }

    // A second click on the same bar item closes its pop-up.
    function toggleSide(s, x, screenName) {
        if (side === s) {
            side = "";
            return;
        }
        sideX = x || 0;
        sideScreen = screenName || "";
        side = s;
    }

    function close() {
        mode = "";
        side = "";
    }
}
