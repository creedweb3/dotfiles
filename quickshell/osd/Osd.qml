import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

// On-screen level: a pill at the bottom centre while volume, microphone or brightness
// changes, from any source (keys, apps, the panel), then it fades. Click-through.
PanelWindow {
    id: osd

    property string kind: "vol"     // vol, mic or bri
    property bool shown: false
    property bool armed: false      // quiet at start-up and right after the output device changes

    readonly property int level: kind === "bri" ? Sys.brightness : kind === "mic" ? (Sys.micMuted ? 0 : Sys.micVolume) : (Sys.muted ? 0 : Sys.volume)
    readonly property string icon: kind === "bri" ? Icons.sun : kind === "mic" ? (Sys.micMuted ? Icons.micoff : Icons.mic) : Icons.volume(Sys.volume, Sys.muted)
    readonly property string label: kind === "bri" ? "brightness" : kind === "mic" ? (Sys.micMuted ? "microphone muted" : "microphone · " + Sys.sourceName) : (Sys.muted || Sys.volume === 0 ? "muted" : "volume · " + Sys.sinkName)

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: shown || card.opacity > 0

    anchors.bottom: true
    margins {
        bottom: 56
    }
    implicitWidth: 320
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "rice-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    function show(k) {
        if (!armed)
            return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        running: true
        interval: 2000
        onTriggered: osd.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1300
        onTriggered: osd.shown = false
    }

    Timer {
        id: rearm
        interval: 600
        onTriggered: osd.armed = true
    }

    Connections {
        target: Sys
        function onVolumeChanged() { osd.show("vol"); }
        function onMutedChanged() { osd.show("vol"); }
        function onMicMutedChanged() { osd.show("mic"); }
        function onBrightnessChanged() { osd.show("bri"); }
        function onSinkChanged() {
            osd.armed = false;
            rearm.restart();
        }
    }

    Rectangle {
        id: card
        width: parent.width
        height: 50
        color: Theme.glass
        border.width: Theme.border
        border.color: Theme.line
        opacity: osd.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                path: osd.icon
                size: 20
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - 38 - parent.spacing * 2
                spacing: 5

                Label {
                    width: parent.width
                    text: osd.label
                    color: Theme.dim
                    font.pixelSize: Theme.smallSize
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: parent.width
                    height: 6
                    color: Theme.alpha(Theme.muted, 0.7)

                    GraphFill {  // style and strength: Settings > Graphs
                        width: parent.width * Math.max(0, Math.min(100, osd.level)) / 100
                        height: parent.height

                        Behavior on width {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                horizontalAlignment: Text.AlignRight
                text: osd.level + "%"
                font.bold: true
            }
        }
    }
}
