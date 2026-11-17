import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../common"
import "Ui.js" as Ui
import "SettingsNetCli.js" as Cli

// Settings > Network > Wired, as the demo's pgWired: the ethernet port's status, speed and address,
// and its IPv4 setup (automatic, or a fixed address, gateway and DNS). Status comes from
// Quickshell.Networking; addresses and the IPv4 setup go through nmcli, as separate arguments.
Column {
    id: page
    spacing: 12

    readonly property var devs: Array.from(Networking.devices.values).filter(d => d.type === DeviceType.Wired)
    property int pick: 0
    readonly property var dev: devs[Math.min(pick, devs.length - 1)] ?? null

    // From nmcli: the profile in use and its IPv4 setup.
    property string uuid: ""
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property string savedMode: "automatic"
    property string mode: "automatic"
    property string error: ""
    property bool busy: false

    Process {
        id: infoProc
        command: ["sh", "-c",
            "u=$(nmcli -g GENERAL.CON-UUID device show \"$1\" 2>/dev/null); printf 'uuid:%s\\n' \"$u\"; " +
            "printf 'ip:%s\\n' \"$(nmcli -g IP4.ADDRESS device show \"$1\" 2>/dev/null | cut -d'|' -f1 | tr -d ' ')\"; " +
            "printf 'gw:%s\\n' \"$(nmcli -g IP4.GATEWAY device show \"$1\" 2>/dev/null)\"; " +
            "printf 'dns:%s\\n' \"$(nmcli -g IP4.DNS device show \"$1\" 2>/dev/null | tr -d ' ' | tr '|' ',')\"; " +
            "[ -n \"$u\" ] && nmcli -t -f ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns connection show uuid \"$u\" 2>/dev/null",
            "sh", page.dev ? page.dev.name : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = Cli.keyValues(text)
                page.uuid = kv.uuid || ""
                page.address = kv.ip || ""
                page.gateway = kv.gw || ""
                page.dns = kv.dns || ""
                page.savedMode = kv["ipv4.method"] === "manual" ? "manual" : "automatic"
                page.mode = page.savedMode
                // Fill the manual fields with the fixed setup, or else with what DHCP gave.
                const fixed = page.savedMode === "manual"
                ipField.text = (fixed ? (kv["ipv4.addresses"] || "").split(",")[0] : page.address).trim()
                gwField.text = fixed ? (kv["ipv4.gateway"] || "").replace(/^--$/, "") : page.gateway
                dnsField.text = fixed ? (kv["ipv4.dns"] || "").replace(/^--$/, "") : page.dns
            }
        }
    }
    function refresh() { if (dev) infoProc.running = true }
    Component.onCompleted: refresh()
    onDevChanged: refresh()
    Connections {
        target: page.dev
        function onStateChanged() { page.refresh() }
    }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            page.busy = false
            if (code !== 0) page.error = applyErr.text.trim().split("\n").pop() || "could not change the address"
            page.refresh()
        }
    }

    function apply() {
        error = ""
        if (!uuid) { error = "this port has no connection profile yet (plug in a cable first)"; return }
        let args
        if (mode === "automatic") {
            args = ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", ""]
        } else {
            const a = Cli.cidr(ipField.text)
            const g = gwField.text.trim()
            const d = dnsField.text.trim()
            if (!a) { error = "address: use the form 192.168.1.20/24"; return }
            if (g && !Cli.isIpv4(g)) { error = "gateway: use the form 192.168.1.1"; return }
            if (d && !Cli.dnsList(d)) { error = "dns: addresses separated by spaces or commas"; return }
            args = ["ipv4.method", "manual", "ipv4.addresses", a, "ipv4.gateway", g, "ipv4.dns", d ? Cli.dnsList(d) : ""]
        }
        busy = true
        applyProc.exec(["sh", "-c", "u=$1; shift; nmcli connection modify uuid \"$u\" \"$@\" && nmcli connection up uuid \"$u\"",
            "sh", uuid].concat(args))
    }

    function statusText() {
        if (!dev) return ""
        if (!dev.nmManaged) return "not managed by NetworkManager"
        if (!dev.hasLink) return "no cable"
        if (dev.connected) return "connected"
        return ConnectionState.toString(dev.state).toLowerCase()
    }

    SetCard {
        title: "ethernet"
        Text {
            visible: page.dev === null
            text: "no ethernet port"
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.dim
        }
        SetSeg {
            visible: page.devs.length > 1
            options: page.devs.map((d, i) => [i, d.name])
            value: Math.min(page.pick, page.devs.length - 1)
            onPicked: v => page.pick = v
        }
        SettingsNetKey { visible: page.dev !== null; key: "status"; value: page.statusText() }
        SettingsNetKey { visible: page.dev !== null && page.dev.hasLink; key: "speed"; value: page.dev ? Cli.speed(page.dev.linkSpeed) : "" }
        SettingsNetKey { visible: page.address !== ""; key: "address"; value: page.address }
        SettingsNetKey { visible: page.gateway !== ""; key: "gateway"; value: page.gateway }
        SettingsNetKey { visible: page.dev !== null; key: "port"; value: page.dev ? page.dev.name + " · " + page.dev.address : "" }
    }

    SetCard {
        visible: page.dev !== null
        title: "ipv4"
        SetRow {
            label: "address"
            SetSeg {
                options: [["automatic", "automatic"], ["manual", "manual"]]
                value: page.mode
                onPicked: v => { page.mode = v; page.error = "" }
            }
        }
        SetRow {
            visible: page.mode === "manual"
            label: "address"
            SettingsNetField { id: ipField; width: parent.width; placeholder: "192.168.1.20/24"; onAccepted: gwField.focusInput() }
        }
        SetRow {
            visible: page.mode === "manual"
            label: "gateway"
            SettingsNetField { id: gwField; width: parent.width; placeholder: "192.168.1.1"; onAccepted: dnsField.focusInput() }
        }
        SetRow {
            visible: page.mode === "manual"
            label: "dns"
            SettingsNetField { id: dnsField; width: parent.width; placeholder: "1.1.1.1, 9.9.9.9"; onAccepted: page.apply() }
        }
        Text {
            visible: page.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: page.error
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.warn
        }
        SetRow {
            visible: page.mode === "manual" || page.mode !== page.savedMode
            label: ""
            SettingsNetButton { text: page.busy ? "applying…" : "apply"; enabled: !page.busy; onClicked: page.apply() }
        }
    }
}
