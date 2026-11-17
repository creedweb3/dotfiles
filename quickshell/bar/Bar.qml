import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../common"

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
    margins {
        top: Theme.barTop
        left: Theme.barSide
        right: Theme.barSide
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "rice-bar"
    WlrLayershell.layer: WlrLayer.Top

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

    Clock {
        screenName: bar.screen.name
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
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

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Music {}

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
            onScrolled: dy => Sys.setVolume(Sys.volume + (dy > 0 ? 5 : -5))
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
