import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../common"
import "../panel"

// The top bar, one per screen. Clock on the left; in the centre the workspaces sit in
// equal halves around the stats (1 2 [stats] 3 4, growing in pairs up to 10); while a special
// workspace shows, its icons take their place (music chat [stats] browser sysmon). Now
// playing, openTHX, sound, Bluetooth, Wi-Fi and battery on the right. The centre never moves.
// Sound / Bluetooth / Wi-Fi: click opens their pop-up, right click mutes or turns off,
// scroll on sound changes the volume.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // Auto-hide (Settings > Bar): the window reaches the screen's top edge, takes no space from
    // windows, and the bar slides up out of it. While hidden only a thin strip along the top edge
    // takes the mouse; touching it slides the bar back, and it hides again a moment after the mouse
    // leaves (never while one of its pop-ups is open).
    readonly property bool autoHide: Prefs.bhide === "auto"
    readonly property bool barShown: !autoHide || popupOpen || hover.hovered || peek.running
    margins {
        top: autoHide ? 0 : Theme.barTop
        left: Math.floor(Theme.barSide)
        right: Math.floor(Theme.barSide)
    }
    implicitHeight: autoHide ? Theme.barTop + Theme.barHeight : Theme.barHeight
    // Shown, it takes its space so windows shrink to make room (nothing is covered); hidden, they
    // grow back into the full height. Both ways the space changes as the 200ms pixel build or
    // un-build starts, so Hyprland's window animation runs alongside it and reads as one motion.
    exclusionMode: autoHide && !barShown ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    // hidden, only the top-edge strip takes the mouse (windows are under the rest)
    mask: autoHide && !barShown ? edgeRegion : null

    Region {
        id: edgeRegion
        item: edge
    }
    Item {
        id: edge
        width: parent.width
        height: 3
    }
    HoverHandler {
        id: hover
    }
    // a workspace switch shows the bar for a moment, so you can see where you are
    Timer {
        id: peek
        interval: 1200
    }
    onActiveWsChanged: if (autoHide) peek.restart()

    WlrLayershell.namespace: "rice-bar"
    // Above the panels' full-screen dim while one is open, back under full-screen windows after.
    // Hyprland stacks a surface that joins a layer on top of the ones already there; the panel
    // windows are mapped from the start, so the bar joining later always lands above them.
    property bool raised: false
    WlrLayershell.layer: raised ? WlrLayer.Overlay : WlrLayer.Top

    // any pop-up: the quick panel / mini player (mode) or a side one like the notification centre,
    // until it has fully gone: lowering the bar as soon as it starts closing would put the bar
    // under the dim for the pixel un-build
    readonly property bool popupOpen: Popup.mode !== "" || Popup.side !== "" || Popup.panelShown || Popup.sideShown
    // the panel windows are always mapped (PanelHost / SideHost), so the bar can rise at once and
    // still land on top of them: no frame with the bar under the dim
    onPopupOpenChanged: bar.raised = popupOpen

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // workspaces 1..10 that have windows (Hyprland drops empty, unfocused ones)
    readonly property var occupied: Hyprland.workspaces.values.filter(w => w.id >= 1 && w.id <= 10 && w.toplevels.values.length > 0).map(w => w.id)
    // shown: at least 4, always an even count, enough for the highest used one
    readonly property int shown: Math.min(10, Math.ceil(Math.max(4, activeWs, ...occupied) / 2) * 2)

    // ---- special workspaces (hypr/hyprland.lua): the one showing on this monitor, from
    // Hyprland's activespecial event ("special:music,DP-1"; empty name when hidden).
    // Before the first event, the monitor's last state from Hyprland.
    property string evSpecial: "?"
    readonly property string special: evSpecial !== "?" ? evSpecial
        : monitor && monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace
            ? String(monitor.lastIpcObject.specialWorkspace.name || "").replace(/^special:/, "") : ""
    readonly property var startedSpecials: Hyprland.workspaces.values.filter(w => w.name.startsWith("special:")).map(w => w.name.slice(8))
    // the rice's four first, in the demo's order, then any others that are running
    readonly property var specials: ["music", "chat", "browser", "sysmon"].concat(startedSpecials.filter(n => !["music", "chat", "browser", "sysmon"].includes(n)))

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial" || !bar.monitor)
                return;
            const i = event.data.lastIndexOf(",");
            if (event.data.slice(i + 1) === bar.monitor.name)
                bar.evSpecial = event.data.slice(0, i).replace(/^special:/, "");
        }
    }

    Component.onCompleted: Hyprland.refreshMonitors()

    // A small pop-up for a bar box: centred under it, on this screen.
    function sideFor(kind, box) {
        Popup.toggleSide(kind, box.mapToItem(null, box.width / 2, 0).x + Theme.barSide, bar.screen.name);
    }

    // everything the bar shows; slides up out of view when auto-hidden
    // The layer's side margin must be a whole number at the ui scale, so it lands a pixel short of
    // Hyprland's 14px window gap (13 at 125%). The content is inset by the rest, so the bar's edges
    // sit exactly on the window borders.
    readonly property real edgeInset: (14 - Math.floor(Math.floor(Theme.barSide) * Theme.uiScale)) / Theme.uiScale
    // Auto-hide: the bar pixel-builds in where the mouse touched the top edge and un-builds when it
    // leaves (as the panels open), fast-start so it answers at once; windows shrink and grow
    // alongside, so nothing is ever covered.
    property real revealX: width / 2
    onBarShownChanged: {
        if (!autoHide)
            return;
        if (barShown) {
            revealX = hover.hovered ? hover.point.position.x : width / 2;
            slide.play();
        } else {
            slide.unplay();
        }
    }
    onAutoHideChanged: slide.progress = autoHide && !barShown ? 0 : 1

    // Where the top window edge is right now, in this window's coordinates: Hyprland moves it
    // between the hidden gap (14px) and below the bar, over 200ms on the "snap" curve
    // (hyprland.lua). The bar only draws above it, so a square never lands on a window that has
    // not moved out of the way yet.
    readonly property real winEdgeHidden: 14 / Theme.uiScale
    readonly property real winEdgeShown: Theme.barTop + Theme.barHeight + 14 / Theme.uiScale
    property real winEdge: !autoHide || barShown ? winEdgeShown : winEdgeHidden
    Behavior on winEdge {
        enabled: bar.autoHide
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    Item {
        id: room
        width: parent.width
        height: bar.autoHide ? Math.max(0, bar.winEdge - 2 / Theme.uiScale) : parent.height
        clip: bar.autoHide

    PixelReveal {
        id: slide
        x: bar.edgeInset
        width: parent.width - bar.edgeInset * 2
        height: Theme.barHeight
        // rides the window's top edge: the bar's bottom stays one gap above it, so the bar travels
        // down with the window (pushing it) while it pixel-builds, and back up as it hides
        y: bar.autoHide ? Math.min(Theme.barTop, bar.winEdge - 14 / Theme.uiScale - Theme.barHeight) : 0
        tile: 14
        duration: 200
        instant: true
        originX: bar.revealX - x

    Clock {
        id: clock
        screenName: bar.screen.name
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: centreRow
        anchors.centerIn: parent
        spacing: Theme.gap

        Repeater {
            model: bar.special === "" ? bar.shown / 2 : 0
            WsBox {
                required property int index
                wsId: index + 1
                occupied: bar.occupied.includes(wsId)
                current: bar.activeWs === wsId
            }
        }

        Repeater {
            model: bar.special === "" ? [] : bar.specials.slice(0, 2)
            SpecialBox {
                required property string modelData
                name: modelData
                occupied: bar.startedSpecials.includes(modelData)
                current: bar.special === modelData
            }
        }

        StatsHub {}

        Repeater {
            model: bar.special === "" ? bar.shown / 2 : 0
            WsBox {
                required property int index
                wsId: bar.shown / 2 + index + 1
                occupied: bar.occupied.includes(wsId)
                current: bar.activeWs === wsId
            }
        }

        Repeater {
            model: bar.special === "" ? [] : bar.specials.slice(2)
            SpecialBox {
                required property string modelData
                name: modelData
                occupied: bar.startedSpecials.includes(modelData)
                current: bar.special === modelData
            }
        }
    }

    // Now playing sits right of the clock and takes only the room left before the workspaces,
    // so a long title never slides under them.
    Music {
        anchors.left: clock.right
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        maxWidth: centreRow.x - Theme.gap * 2 - (clock.x + clock.width + Theme.gap)
    }

    Row {
        id: sysRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        OpenThx {}

        SysBox {
            id: soundBox
            active: Popup.side === "sound"
            icon: Icons.volume(Sys.volume, Sys.muted)
            value: Sys.muted || Sys.volume === 0 ? "muted" : Sys.volume + "%"
            off: Sys.muted || Sys.volume === 0
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Sys.toggleMute();
                else
                    bar.sideFor("sound", soundBox);
            }
            onScrolled: dy => Sys.setVolume(Sys.volume + (dy > 0 ? 1 : -1))
        }

        SysBox {
            id: btBox
            active: Popup.side === "bt"
            icon: Icons.bt + (Sys.btOn ? "" : Icons.slash)
            value: Sys.btName
            off: !Sys.btOn
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Sys.toggleBt();
                else
                    bar.sideFor("bt", btBox);
            }
        }

        SysBox {
            id: wifiBox
            active: Popup.side === "wifi"
            icon: Sys.wifiNet || !Sys.wired ? Icons.wifi(Sys.wifiOn ? Sys.wifiBars : 3, !Sys.wifiOn) : Icons.wired
            value: Sys.netName
            off: !Sys.wifiNet && !Sys.wired
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Sys.toggleWifi();
                else
                    bar.sideFor("wifi", wifiBox);
            }
        }

        SysBox {
            readonly property var battery: UPower.displayDevice
            visible: battery !== null && battery.isLaptopBattery && battery.isPresent
            // percentage is a 0..1 fraction (energy / energyCapacity)
            readonly property int level: battery ? Math.round(battery.percentage * (battery.percentage <= 1 ? 100 : 1)) : 0
            icon: Icons.battery
            value: level + "%"
            off: level <= 12
        }
    }
    }
    }
}
