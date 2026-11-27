import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

// Notification pop-ups: a stack in the bottom left corner, newest at the bottom, at
// most three plus "+N more". The line along the bottom is the time left; pointing at a toast
// pauses it. Critical ones (red edge) stay until dismissed. Clicking a toast opens the centre.
// Colour is Settings > Panels > notifications (Prefs.ntone): wallpaper tint or neutral.
PanelWindow {
    id: root

    readonly property var shown: Notifs.toasts.slice(0, 3)
    readonly property int extra: Math.max(0, Notifs.toasts.length - 3)
    readonly property bool tinted: (Prefs.ntone ?? "tinted") !== "neutral"

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: Notifs.toasts.length > 0

    anchors {
        bottom: true
        left: true
    }
    // in line with the windows' edges (Hyprland's gaps_out, which the ui scale does not touch)
    margins {
        bottom: Math.round(14 / Theme.uiScale) + 6
        left: Math.round(14 / Theme.uiScale) + 6
    }
    implicitWidth: 280
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "rice-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function openCentre() {
        Popup.sideScreen = screen ? screen.name : "";
        Popup.side = "nc";
    }

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Rectangle {
            visible: root.extra > 0
            anchors.left: parent.left
            width: more.implicitWidth + 16
            height: 20
            color: Theme.alpha(Theme.bg, 0.8)
            border.width: 1
            border.color: Theme.muted

            Label {
                id: more
                anchors.centerIn: parent
                text: "+" + root.extra + " more"
                color: Theme.dim
                font.pixelSize: Theme.smallSize
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openCentre()
            }
        }

        Repeater {
            // ScriptModel keeps each toast's delegate (and its timer) when the list changes
            model: ScriptModel {
                // newest nearest the corner
                values: root.shown.slice().reverse()
            }

            Toast {
                required property var modelData
                n: modelData
                width: stack.width
                tinted: root.tinted
                onOpenCentre: root.openCentre()
            }
        }

    }
}
