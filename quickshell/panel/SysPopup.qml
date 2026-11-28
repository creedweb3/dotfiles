import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import "../common"
import "../overlays/SettingsNetCli.js" as Cli

// The small pop-ups under the bar's sound, Bluetooth and Wi-Fi icons, as the demo:
//   sound  volume, the output devices (click one to use it), openTHX spatial on / off
//   bt     on / off, then the paired devices (click to connect or disconnect)
//   wifi   on / off, then the networks in range (click a saved or open one to join)
// "more settings" opens the matching Settings page.
Rectangle {
    id: root

    required property string kind
    readonly property string page: ({ sound: "out", bt: "bt", wifi: "wifi" })[kind] || "out"

    width: 390
    height: col.implicitHeight + 28
    color: Theme.glass
    border.width: Theme.border
    border.color: Theme.line

    // swallow clicks so they do not reach the scrim behind and close the pop-up
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        // ---- sound
        Card {
            visible: root.kind === "sound"
            width: parent.width
            title: "volume"

            RangeRow {
                width: parent.width
                label: "level"
                value: Sys.volume
                onMoved: v => Sys.setVolume(v)
            }
        }

        Card {
            visible: root.kind === "sound"
            width: parent.width
            title: "output"

            Repeater {
                model: root.kind === "sound" ? Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream) : []

                ListRow {
                    required property var modelData
                    width: parent.width
                    name: Sys.deviceName(modelData)
                    detail: modelData === Pipewire.defaultAudioSink ? "in use" : ""
                    on: modelData === Pipewire.defaultAudioSink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }

        Card {
            visible: root.kind === "sound" && thx.state !== ""
            width: parent.width
            title: "openTHX"

            Item {
                width: parent.width
                height: 22

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "spatial audio"
                    color: Theme.dim
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: ["on", "off"]

                        Rectangle {
                            required property string modelData
                            readonly property bool picked: (thx.state === "on") === (modelData === "on")
                            width: 44
                            height: 22
                            color: picked ? Theme.alpha(Theme.accent, 0.2) : "transparent"
                            border.width: 1
                            border.color: picked ? Theme.accent : Theme.muted

                            Label {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: parent.picked ? Theme.accent : Theme.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!parent.picked) thx.toggle()
                            }
                        }
                    }
                }
            }
        }

        // ---- Bluetooth
        Card {
            visible: root.kind === "bt"
            width: parent.width

            Item {
                width: parent.width
                height: 20

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
                    font.bold: true
                }
                Switch2 {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Sys.btOn
                    onToggled: Sys.toggleBt()
                }
            }
        }

        Card {
            visible: root.kind === "bt" && Sys.btOn
            width: parent.width
            title: "devices"

            Label {
                visible: btList.count === 0
                text: "no paired devices yet: scan below"
                color: Theme.dim
            }

            Repeater {
                id: btList
                model: root.kind === "bt" && Sys.btAdapter ? Sys.btAdapter.devices.values.filter(d => (d.paired || d.bonded) && !Sys.btHidden(d)) : []

                ListRow {
                    required property var modelData
                    width: parent.width
                    name: modelData.name || modelData.deviceName
                    detail: modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                        : modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
                        : modelData.connected ? "connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        : "paired"
                    on: modelData.connected
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
        }

        // new devices: scan here (stops on its own after 30 s), click one to pair, trust and connect it
        Card {
            id: btNew
            visible: root.kind === "bt" && Sys.btOn
            width: parent.width
            title: "new devices"

            readonly property bool scanning: Sys.btAdapter !== null && Sys.btAdapter.discovering
            // unnamed devices in range are only addresses (mostly phones' and TVs' beacons): left out
            readonly property var found: Sys.btAdapter ? Sys.btAdapter.devices.values.filter(d => !d.paired && !d.bonded && d.deviceName && !Sys.btHidden(d)) : []

            function scan(on) {
                if (!Sys.btAdapter)
                    return;
                Sys.btAdapter.discovering = on;
                if (on)
                    btScanStop.restart();
            }
            Timer {
                id: btScanStop
                interval: 30000
                onTriggered: btNew.scan(false)
            }

            ListRow {
                width: parent.width
                name: btNew.scanning ? "looking for devices…" : "scan for devices"
                detail: btNew.scanning ? "stop" : "put headphones in pairing mode first"
                on: btNew.scanning
                onClicked: btNew.scan(!btNew.scanning)
            }

            Repeater {
                model: root.kind === "bt" ? btNew.found : []

                ListRow {
                    id: newRow
                    required property var modelData
                    width: parent.width
                    name: modelData.name || modelData.deviceName
                    detail: modelData.pairing ? "pairing…" : "pair"
                    onClicked: {
                        if (modelData.pairing)
                            return modelData.cancelPair();
                        modelData.trusted = true;   // so it reconnects on its own later
                        modelData.pair();
                    }
                    Connections {
                        target: newRow.modelData
                        ignoreUnknownSignals: true
                        function onPairedChanged() {
                            if (newRow.modelData.paired)
                                newRow.modelData.connect();
                        }
                    }
                }
            }
        }

        // ---- Wi-Fi
        Card {
            visible: root.kind === "wifi"
            width: parent.width

            Item {
                width: parent.width
                height: 20

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    font.bold: true
                }
                Switch2 {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Sys.wifiOn
                    onToggled: Sys.toggleWifi()
                }
            }
        }

        Card {
            visible: root.kind === "wifi" && Sys.wifiOn && Sys.wifiDevice !== null
            width: parent.width
            title: "networks"

            Label {
                visible: netList.count === 0
                text: "searching…"
                color: Theme.dim
            }

            Repeater {
                id: netList
                model: root.kind === "wifi" && Sys.wifiDevice ? Array.from(Sys.wifiDevice.networks.values).filter(n => n.name)
                    .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)).slice(0, 8) : []

                ListRow {
                    required property var modelData
                    readonly property bool open: Cli.isOpen(modelData.security)
                    width: parent.width
                    name: modelData.name
                    detail: (modelData.connected ? "connected" : modelData.known ? "saved" : open ? "open" : "secured")
                        + " · " + "▂▄▆█".slice(0, Cli.bars(modelData.signalStrength))
                    on: modelData.connected
                    onClicked: {
                        if (modelData.connected)
                            return;
                        // a new secured network needs its password: the Wi-Fi page asks for it
                        if (modelData.known || open)
                            modelData.connect();
                        else
                            root.more();
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 28

            Rectangle {
                anchors.right: parent.right
                width: moreLabel.implicitWidth + 24
                height: 28
                color: "transparent"
                border.width: 1
                border.color: moreMouse.containsMouse ? Theme.accent : Theme.muted

                Label {
                    id: moreLabel
                    anchors.centerIn: parent
                    text: "more settings"
                    color: moreMouse.containsMouse ? Theme.accent : Theme.fg
                }
                MouseArea {
                    id: moreMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.more()
                }
            }
        }
    }

    function more() {
        Popup.close();
        Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "settings", "openPage", page]);
    }

    // openTHX state from `openthx-ctl bar`: "on", "off" (spatial bypassed), "" (not installed or not running)
    QtObject {
        id: thx

        readonly property string ctl: Theme.home + "/.local/bin/openthx-ctl"
        property string state: ""

        function toggle() {
            Quickshell.execDetached([ctl, "toggle"]);
            thxLater.restart();
        }
    }

    Process {
        id: thxPoll
        running: root.kind === "sound"
        command: [thx.ctl, "bar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).class || "";
                    thx.state = c === "bypass" ? "off" : c === "off" || c === "busy" || c === "" ? "" : "on";
                } catch (e) {
                    thx.state = "";
                }
            }
        }
    }

    Timer {
        id: thxLater
        interval: 600
        onTriggered: if (!thxPoll.running) thxPoll.running = true
    }
}
