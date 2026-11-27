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
        function onSideChanged() {
            if (Popup.side !== "")
                host.shownSide = Popup.side;
        }
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
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, Prefs.scrimAlpha)

            MouseArea {
                anchors.fill: parent
                onClicked: Popup.close()
            }
        }

        Loader {
            id: loader
            // a fresh pop-up each time it opens (after the last one faded), so the centre
            // resets its month and marks everything read
            active: host.visible
            y: Theme.popupTop - host.margins.top
            x: host.shownSide === "nc" ? Theme.barSide
                : Math.round(Math.max(Theme.barSide, Math.min(Popup.sideX - width / 2, host.width - Theme.barSide - width)))
            sourceComponent: host.shownSide === "nc" ? centre : small
            layer.enabled: Prefs.shadow
            layer.effect: PanelShadow {}
        }
    }

    Component {
        id: centre
        NotifCentre {
            height: host.height - loader.y - Theme.barSide
        }
    }
    Component {
        id: small
        SysPopup {
            kind: host.shownSide
        }
    }
}
