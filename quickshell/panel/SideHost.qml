import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

// Holds the notification centre (left, under the clock, down to the bottom edge) and the
// small sound / Bluetooth / Wi-Fi pop-ups (under their bar icon), on the screen whose bar
// opened them. Same behaviour as PanelHost: dim and/or shadow per Settings > Panels,
// clicking outside or Escape closes, the bar stays clickable.
PanelWindow {
    id: host

    readonly property bool open: Popup.side !== ""
    // keeps the last pop-up drawn while it fades out
    property string shownSide: "nc"

    screen: Quickshell.screens.find(s => s.name === Popup.sideScreen)
        ?? Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
        ?? Quickshell.screens[0]
    // Always mapped, empty and click-through while closed: opening then draws into a window that
    // already exists, so there is no Hyprland fade-in, no flash of the bar under the dim, and it
    // opens a little sooner. `live` is when it is on screen (closing animation included).
    readonly property bool live: open || content.opacity > 0 || reveal.busy
    visible: true
    mask: live ? null : noInput
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
        property: "sideShown"
        value: host.live
    }

    Connections {
        target: Popup
        function onSideChanged() {
            if (Popup.side !== "") {
                host.shownSide = Popup.side;
                reveal.play();
            } else {
                reveal.unplay();
            }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: host.open || reveal.busy ? 1 : 0
        focus: true

        Keys.onEscapePressed: Popup.close()

        Rectangle {
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

        // slides down out from under the bar and/or pixel-builds (PanelReveal, Settings > Panels > open motion)
        PanelReveal {
            id: reveal
            y: Theme.popupTop - host.margins.top
            x: host.shownSide === "nc" ? Theme.barSide
                : Math.round(Math.max(Theme.barSide, Math.min(Popup.sideX - width / 2, host.width - Theme.barSide - width)))
            width: loader.width
            height: loader.height
            originX: host.shownSide === "nc" ? 0 : Popup.sideX - x

            Loader {
                id: loader
                // a fresh pop-up each time it opens (after the last one faded), so the centre
                // resets its month and marks everything read
                active: host.live
                sourceComponent: host.shownSide === "nc" ? centre : small
                layer.enabled: Prefs.shadow
                layer.effect: PanelShadow {}
            }
        }
    }

    Component {
        id: centre
        NotifCentre {
            height: host.height - reveal.y - Theme.barSide
        }
    }
    Component {
        id: small
        SysPopup {
            kind: host.shownSide
        }
    }
}
