import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../common"
import "Ui.js" as Ui
import "SettingsNetCli.js" as Cli

// Settings > Network > Wi-Fi, as the demo's pgWifi: on/off switch, the networks in range (click one
// to join), details of the chosen one with disconnect and forget, and joining a hidden network.
// Quickshell.Networking (NetworkManager) does the work; nmcli only fills in the address and band,
// and adds hidden networks. Passwords go to NetworkManager directly or through nmcli's stdin,
// never through a command line.
Column {
    id: page
    spacing: 12

    readonly property var dev: Array.from(Networking.devices.values).find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool on: Networking.wifiEnabled
    readonly property var nets: dev ? Array.from(dev.networks.values).filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []
    readonly property var current: nets.find(n => n.connected) ?? null
    property var sel: null
    // The network the details card shows: the one last clicked, else the connected one.
    readonly property var shown: sel && nets.includes(sel) ? sel : current
    property string asking: ""   // name of the network waiting for a password
    property string error: ""
    property string address: ""
    property string band: ""

    // Scan while this page is open; Binding puts the old value back when the page closes.
    Binding {
        when: page.dev !== null && page.on
        target: page.dev
        property: "scannerEnabled"
        value: true
        restoreMode: Binding.RestoreBindingOrValue
    }

    function join(net) {
        sel = net
        error = ""
        if (net.connected) return
        if (net.known || Cli.isOpen(net.security)) {
            asking = ""
            net.connect()
        } else if (Cli.takesPsk(net.security)) {
            asking = net.name
            Qt.callLater(() => pskField.focusInput())
        } else {
            error = "this network needs an enterprise login: set it up in the connection editor"
        }
    }

    function sendPsk() {
        if (!shown || !pskField.text) return
        shown.connectWithPsk(pskField.text)
        pskField.text = ""
        asking = ""
    }

    Connections {
        target: page.shown
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets && Cli.takesPsk(page.shown.security)) {
                page.asking = page.shown.name
                page.error = "wrong or missing password"
            } else {
                page.error = "could not connect: " + ConnectionFailReason.toString(reason)
            }
        }
    }

    // Address and band of the connection in use (Networking has neither).
    Process {
        id: infoProc
        command: ["sh", "-c",
            "printf 'ip:%s\\n' \"$(nmcli -g IP4.ADDRESS device show \"$1\" 2>/dev/null | cut -d'|' -f1)\"; " +
            "printf 'freq:%s\\n' \"$(nmcli -t -f IN-USE,FREQ device wifi list ifname \"$1\" --rescan no 2>/dev/null | sed -n 's/^\\*://p' | head -n 1)\"",
            "sh", page.dev ? page.dev.name : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = Cli.keyValues(text)
                page.address = (kv.ip || "").trim()
                const mhz = parseInt(kv.freq || "")
                page.band = !mhz ? "" : mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz"
            }
        }
    }
    function refreshInfo() {
        address = ""; band = ""
        if (!dev || !current) return
        infoProc.running = true
        infoLater.restart()   // DHCP may hand out the address a moment after connecting
    }
    Timer { id: infoLater; interval: 3000; onTriggered: if (page.dev && page.current) infoProc.running = true }
    onCurrentChanged: refreshInfo()
    Component.onCompleted: refreshInfo()

    // Hidden networks: nmcli adds the profile, then reads the password from stdin (passwd-file).
    // A fresh Process per try, since its stdin closes for good after the password is written.
    Component {
        id: hiddenJob
        Process {
            id: job
            property string psk
            stdinEnabled: true
            stderr: StdioCollector { id: jobErr }
            onStarted: {
                if (psk) write("802-11-wireless-security.psk:" + psk + "\n")
                psk = ""
                stdinEnabled = false
            }
            onExited: code => {
                page.hiddenBusy = false
                if (code === 0) { hidSsid.text = ""; page.hiddenOpen = false }
                else page.error = (jobErr.text.trim().split("\n").pop() || "could not join the hidden network")
                job.destroy()
            }
        }
    }
    property bool hiddenOpen: false
    property bool hiddenBusy: false
    function joinHidden() {
        const ssid = hidSsid.text.trim()
        if (!dev || !ssid || hiddenBusy) return
        error = ""
        hiddenBusy = true
        const secured = hidPsk.text ? "1" : "0"
        const job = hiddenJob.createObject(page, {
            psk: hidPsk.text,
            command: ["sh", "-c",
                "set -u; sec=; [ \"$3\" = 1 ] && sec='wifi-sec.key-mgmt wpa-psk'; " +
                "out=$(nmcli connection add type wifi ifname \"$1\" con-name \"$2\" ssid \"$2\" 802-11-wireless.hidden yes $sec) || exit 1; " +
                "uuid=$(printf '%s' \"$out\" | grep -oE '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}' | tail -n 1); " +
                "[ -n \"$uuid\" ] || exit 1; " +
                "if [ \"$3\" = 1 ]; then nmcli connection up uuid \"$uuid\" passwd-file /dev/stdin; else nmcli connection up uuid \"$uuid\" </dev/null; fi " +
                "|| { nmcli connection delete uuid \"$uuid\" >/dev/null 2>&1; exit 1; }",
                "sh", dev.name, ssid, secured]
        })
        hidPsk.text = ""
        job.running = true
    }

    SetCard {
        title: "wi-fi"
        RowLayout {
            width: parent.width
            Text {
                text: "wi-fi"
                Layout.preferredWidth: 132
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.dim
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: !page.dev ? "no wi-fi adapter"
                    : !Networking.wifiHardwareEnabled ? "blocked by a hardware switch"
                    : !page.on ? "off" : page.current ? "connected to " + page.current.name : "not connected"
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: 11 }
                color: Theme.dim
            }
            SettingsNetSwitch {
                on: page.on
                enabled: page.dev !== null && Networking.wifiHardwareEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Repeater {
            model: page.on ? page.nets : []
            Rectangle {
                id: netRow
                required property var modelData
                readonly property bool picked: modelData === page.shown
                width: parent.width
                height: 30
                color: netArea.containsMouse ? Ui.alpha(Theme.accent, 0.10) : "transparent"
                border.color: picked ? Theme.accent : "transparent"
                Text {
                    anchors { left: parent.left; leftMargin: 8; right: netNote.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: netRow.modelData.name
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: netRow.modelData.connected ? Theme.fg : Theme.dim
                }
                Text {
                    id: netNote
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: [netRow.modelData.stateChanging ? "connecting…" : netRow.modelData.connected ? "connected"
                            : netRow.modelData.known ? "saved" : "",
                        Cli.security(netRow.modelData.security),
                        Cli.bars(netRow.modelData.signalStrength) + "/4"].filter(x => x).join(" · ")
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: Theme.dim
                }
                MouseArea {
                    id: netArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.join(netRow.modelData)
                }
            }
        }
        Text {
            visible: page.on && page.dev !== null && page.nets.length === 0
            text: "looking for networks…"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
    }

    SetCard {
        visible: page.on && page.shown !== null
        title: page.shown ? page.shown.name : ""

        SettingsNetKey { key: "signal"; value: page.shown ? Cli.bars(page.shown.signalStrength) + "/4" : "" }
        SettingsNetKey { key: "security"; value: page.shown ? Cli.security(page.shown.security) : "" }
        SettingsNetKey { visible: page.shown === page.current && page.band !== ""; key: "band"; value: page.band }
        SettingsNetKey { visible: page.shown === page.current && page.address !== ""; key: "address"; value: page.address }

        SetRow {
            visible: page.shown !== null && page.asking === page.shown.name
            label: "password"
            RowLayout {
                width: parent.width
                spacing: 8
                SettingsNetField {
                    id: pskField
                    Layout.fillWidth: true
                    secret: true
                    placeholder: "wi-fi password"
                    onAccepted: page.sendPsk()
                }
                SettingsNetButton { text: "join"; onClicked: page.sendPsk() }
            }
        }

        Text {
            visible: page.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: page.error
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.warn
        }

        Row {
            spacing: 8
            SettingsNetButton {
                visible: page.shown !== null && !page.shown.connected && page.asking !== page.shown.name
                text: "join"
                onClicked: page.join(page.shown)
            }
            SettingsNetButton {
                visible: page.shown !== null && page.shown.connected
                text: "disconnect"
                onClicked: page.shown.disconnect()
            }
            SettingsNetButton {
                visible: page.shown !== null && page.shown.known
                text: "forget"
                warn: true
                onClicked: { page.shown.forget(); page.sel = null }
            }
            SettingsNetButton {
                visible: page.shown !== null && !Cli.isOpen(page.shown.security) && !Cli.takesPsk(page.shown.security)
                text: "connection editor"
                onClicked: Quickshell.execDetached(["nm-connection-editor"])
            }
        }
    }

    SetCard {
        visible: page.on && page.dev !== null
        title: "other"
        SetRow {
            visible: !page.hiddenOpen
            label: "hidden network"
            SettingsNetButton { text: "join hidden network…"; onClicked: { page.hiddenOpen = true; Qt.callLater(() => hidSsid.focusInput()) } }
        }
        SetRow {
            visible: page.hiddenOpen
            label: "name"
            SettingsNetField { id: hidSsid; width: parent.width; placeholder: "network name (SSID)"; onAccepted: hidPsk.focusInput() }
        }
        SetRow {
            visible: page.hiddenOpen
            label: "password"
            SettingsNetField { id: hidPsk; width: parent.width; secret: true; placeholder: "empty for an open network"; onAccepted: page.joinHidden() }
        }
        Row {
            visible: page.hiddenOpen
            spacing: 8
            SettingsNetButton { text: page.hiddenBusy ? "joining…" : "join"; enabled: !page.hiddenBusy; onClicked: page.joinHidden() }
            SettingsNetButton { text: "cancel"; onClicked: { page.hiddenOpen = false; hidSsid.text = ""; hidPsk.text = "" } }
        }
    }
}
