import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// A full-screen layer on the focused monitor for the rice's pop-ups. It takes the keyboard while open
// and dims what is behind it; a click on the dimmed part emits dismissed().
// Blur behind needs a Hyprland layer rule for the namespace "rice-<name>".
PanelWindow {
    id: win

    property string name
    property bool open: false
    property real dim: 0.45
    signal dismissed()
    default property alias content: holder.data

    // Move to the focused monitor first, then map, so the layer opens where the user is.
    function show() {
        const m = Hyprland.focusedMonitor
        const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
        if (s) win.screen = s
        win.open = true
    }

    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-" + name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, win.dim)
        MouseArea { anchors.fill: parent; onClicked: win.dismissed() }
    }
    Item { id: holder; anchors.fill: parent }
}
