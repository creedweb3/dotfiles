import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../common"

// Holds the bar's pop-ups (quick panel, mini player) on the focused screen.
// A full-screen layer below the bar strip dims what is behind and/or the pop-up casts a
// shadow (Settings > Panels > behind open panels: Prefs.depth, Prefs.sdim); clicking
// outside or pressing Escape closes. The bar itself stays clickable.
// IPC: `qs -c rice ipc call panel toggle` (SUPER+C), `... panel system disk` (a system detail view).
PanelWindow {
    id: host

    readonly property bool open: Popup.mode !== ""
    // closing leaves the system tab's detail view, so the next opening starts on the tab
    onOpenChanged: if (!open) Stats.view = ""
    // keeps the last pop-up drawn while it fades out
    property string shownMode: "panel"

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: open || content.opacity > 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // the whole screen: the dim and blur run behind the bar too, so there is no bright band
    // around it; the bar rises above this layer while it is open (Bar.qml)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "rice-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Popup
        function onModeChanged() {
            if (Popup.mode !== "")
                host.shownMode = Popup.mode;
        }
    }

    Binding {
        target: Stats
        property: "detail"
        value: host.open && host.shownMode === "panel"
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: host.open ? 1 : 0
        focus: true

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Keys.onEscapePressed: Popup.close()

        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, Prefs.scrimAlpha)

            MouseArea {
                anchors.fill: parent
                onClicked: Popup.close()
            }
        }

        Loader {
            // top edge in line with the windows' top edges
            y: Theme.popupTop - host.margins.top
            x: host.shownMode === "player" ? Math.max(Theme.barSide, Math.min(Popup.playerRight - width, host.width - Theme.barSide - width)) : Math.round((host.width - width) / 2)
            sourceComponent: host.shownMode === "player" ? player : panel
            layer.enabled: Prefs.shadow
            layer.effect: PanelShadow {}
        }
    }

    Component {
        id: panel
        QuickPanel {}
    }
    Component {
        id: player
        MiniPlayer {}
    }

    IpcHandler {
        target: "panel"
        function toggle(): void {
            Popup.toggle("panel");
        }
        // open the quick panel on its media tab
        function media(): void {
            Popup.open("panel", "media");
        }
        // the system tab, on one card's detail view (cpu, mem, gpu, disk, net) or "" for all
        function system(view: string): void {
            Stats.openView(["", "cpu", "mem", "gpu", "disk", "net"].indexOf(view) >= 0 ? view : "");
        }
    }
}
