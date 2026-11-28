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
// IPC: `qs -c rice ipc call panel toggle` (SUPER+X), `... panel system disk` (a system detail view).
PanelWindow {
    id: host

    readonly property bool open: Popup.mode !== ""
    // closing leaves the system tab's detail view, so the next opening starts on the tab
    onOpenChanged: if (!open) Stats.view = ""
    // keeps the last pop-up drawn while it fades out
    property string shownMode: "panel"

    // follows the focused monitor only while closed: once open it stays put, so moving focus to
    // another monitor never carries the panel over (and on top of that monitor's bar)
    Binding on screen {
        when: !host.live
        value: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    // a move maps the window again, on top of its layer: let the bars rise back above it (Bar.qml)
    onScreenChanged: Popup.hostMoved()
    // Always mapped, empty and click-through while closed: opening then draws into a window that
    // already exists, so there is no Hyprland fade-in, no flash of the bar under the dim, and it
    // opens a little sooner. `live` is when it is on screen (closing animation included).
    readonly property bool live: open || content.opacity > 0 || reveal.busy
    visible: true
    // only takes the mouse while open: during the closing animation (or if it ever stuck) clicks pass
    // through, so a pop-up that is going away can never swallow the bar or the desktop
    mask: open ? null : noInput
    Region {
        id: noInput
    }

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

    // tell the bar (Bar.qml) while this is on screen, closing animation included
    Binding {
        target: Popup
        property: "panelShown"
        value: host.live
    }

    Connections {
        target: Popup
        function onModeChanged() {
            if (Popup.mode !== "") {
                host.shownMode = Popup.mode;
                reveal.play();
            } else {
                reveal.unplay();
            }
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
        opacity: host.open || reveal.busy ? 1 : 0
        focus: true

        Keys.onEscapePressed: Popup.close()

        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, Prefs.scrimAlpha)
            // fades out while the panel un-builds, not after it
            opacity: host.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Popup.close()
            }
        }

        // the panel slides down out from under the bar and/or pixel-builds (PanelReveal, Settings > Panels > open motion)
        PanelReveal {
            id: reveal
            // top edge in line with the windows' top edges
            y: Theme.popupTop - host.margins.top
            x: host.shownMode === "player" ? Math.max(Theme.barSide, Math.min(Popup.playerRight - width, host.width - Theme.barSide - width)) : Theme.centre(host.width, width)
            width: ld.width
            height: ld.height
            // mini player: from the music box (its left part, next to the clock); quick panel: the centre
            originX: host.shownMode === "player" ? Popup.playerRight - 248 + 60 - x : width / 2

            Loader {
                id: ld
                sourceComponent: host.shownMode === "player" ? player : panel
                layer.enabled: Prefs.shadow
                layer.effect: PanelShadow {}
            }
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
        // close whatever pop-up this host shows (used by rice-gapcheck to start from a known state)
        function close(): void {
            Popup.close();
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
