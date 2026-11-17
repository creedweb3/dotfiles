import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"
import "Ui.js" as Ui
import "SettingsNetCli.js" as Cli

// Settings > Network > VPN, as the demo's pgVpn: every NetworkManager VPN and WireGuard profile with
// an on/off switch, and importing a WireGuard (.conf) or OpenVPN (.ovpn) file. All through nmcli,
// each value a separate argument. Quickshell.Networking does not list VPN profiles, so the list is
// re-read every few seconds while the page is open.
Column {
    id: page
    spacing: 12

    property var tunnels: []      // [{name, uuid, type, active}]
    property bool loaded: false
    property string busy: ""      // uuid being switched
    property string error: ""
    property string note: ""

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.tunnels = text.split("\n").filter(l => l).map(Cli.fields)
                    .filter(f => f[2] === "vpn" || f[2] === "wireguard")
                    .map(f => ({ name: f[0], uuid: f[1], type: f[2], active: f[3] === "yes" }))
                page.loaded = true
            }
        }
    }
    function refresh() { listProc.running = true }
    Component.onCompleted: refresh()
    Timer { interval: 3000; running: true; repeat: true; onTriggered: if (!page.busy) page.refresh() }

    Process {
        id: actProc
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            if (code !== 0) page.error = actErr.text.trim().split("\n").pop()
                || "could not switch the tunnel; if it needs a password, save it in the connection editor"
            page.busy = ""
            page.refresh()
        }
    }
    function toggle(t) {
        if (busy) return
        error = ""
        busy = t.uuid
        actProc.exec(["nmcli", "connection", t.active ? "down" : "up", "uuid", t.uuid])
    }

    Process {
        id: importProc
        stdout: StdioCollector { id: importOut }
        stderr: StdioCollector { id: importErr }
        onExited: code => {
            if (code === 0) { page.note = importOut.text.trim().split("\n").pop() || "imported"; fileField.text = "" }
            else page.error = importErr.text.trim().split("\n").pop() || "could not import the file"
            page.refresh()
        }
    }
    function importFile() {
        error = ""; note = ""
        let path = fileField.text.trim()
        if (!path) return
        if (path === "~" || path.startsWith("~/")) path = Quickshell.env("HOME") + path.slice(1)
        const type = /\.conf$/i.test(path) ? "wireguard" : /\.ovpn$/i.test(path) ? "openvpn" : ""
        if (!type) { error = "use a WireGuard .conf or an OpenVPN .ovpn file"; return }
        importProc.exec(["nmcli", "connection", "import", "type", type, "file", path])
    }

    SetCard {
        title: "tunnels"
        Repeater {
            model: page.tunnels
            RowLayout {
                required property var modelData
                width: parent.width
                Text {
                    Layout.preferredWidth: 132
                    text: modelData.name
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: modelData.active ? Theme.fg : Theme.dim
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.busy === modelData.uuid ? (modelData.active ? "disconnecting…" : "connecting…")
                        : modelData.active ? "connected" : modelData.type === "wireguard" ? "WireGuard" : "VPN"
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: Theme.dim
                }
                SettingsNetSwitch {
                    on: modelData.active
                    enabled: page.busy === ""
                    onToggled: page.toggle(modelData)
                }
            }
        }
        Text {
            visible: page.loaded && page.tunnels.length === 0
            text: "no VPN or WireGuard profiles yet"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
        Text {
            visible: page.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: page.error
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.warn
        }
        SettingsNetButton {
            visible: page.error !== ""
            text: "connection editor"
            onClicked: Quickshell.execDetached(["nm-connection-editor"])
        }
    }

    SetCard {
        title: "add"
        SetRow {
            label: "import file"
            RowLayout {
                width: parent.width
                spacing: 8
                SettingsNetField {
                    id: fileField
                    Layout.fillWidth: true
                    placeholder: "~/Downloads/home.conf"
                    onAccepted: page.importFile()
                }
                SettingsNetButton { text: "import"; onClicked: page.importFile() }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: page.note || "WireGuard .conf or OpenVPN .ovpn; the profile is named after the file"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
