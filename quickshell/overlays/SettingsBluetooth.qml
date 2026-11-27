import QtQuick
import Quickshell.Bluetooth
import "../common"
import "Ui.js" as Ui

// Settings > Bluetooth > Devices, as the demo's pgBt, from BlueZ (Quickshell.Bluetooth):
//   bluetooth on/off and "visible to others" (adapter powered / discoverable)
//   my devices    paired ones: click to select, then connect / disconnect, trust, forget
//   new devices   scan for devices in pairing mode; click one to pair, trust and connect it
Column {
    id: page
    spacing: 12

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: !!adapter && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values.filter(d => !Sys.btHidden(d)) : []
    readonly property var known: devices.filter(d => d.paired || d.bonded)
    // Unnamed devices in range are only addresses; leave them out of the list.
    readonly property var found: devices.filter(d => !d.paired && !d.bonded && d.deviceName)
    property string selected: ""       // address of the selected paired device
    readonly property var sel: known.find(d => d.address === selected) || known[0] || null
    property bool scanned: false       // a scan was started here (stopped again when the page closes)
    property var pairing: null         // device being paired from this page; trusted and connected once paired

    function kindOf(d) {
        const k = {"audio-headset": "headset", "audio-headphones": "headphones", "audio-card": "speaker",
            "input-mouse": "mouse", "input-keyboard": "keyboard", "input-gaming": "controller", "input-tablet": "tablet",
            "phone": "phone", "computer": "computer", "camera-photo": "camera", "printer": "printer"}
        return k[d.icon] || (d.icon ? d.icon.split("-").pop() : "device")
    }
    function statusOf(d) {
        const s = d.state === BluetoothDeviceState.Connecting ? "connecting…"
            : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
            : d.connected ? "connected" : "paired"
        return kindOf(d) + " · " + s + (d.connected && d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "")
    }
    function scan(start) {
        if (!adapter) return
        adapter.discovering = start
        scanned = start
    }
    function pair(d) {
        pairing = d
        d.pair()
    }

    Connections {
        target: page.pairing
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = page.pairing
            if (!d || !d.paired) return
            d.trusted = true   // so it reconnects on its own later
            d.connect()
            page.selected = d.address
            page.pairing = null
        }
    }
    Component.onDestruction: if (scanned && adapter) adapter.discovering = false

    // A small outlined button, as the demo's .sbtn; `danger` outlines it in the warning colour.
    component Btn: Rectangle {
        id: btn
        property string text
        property bool danger: false
        signal clicked()
        width: btnText.implicitWidth + 20
        height: 24
        color: area.containsMouse ? Ui.alpha(danger ? Theme.warn : Theme.accent, 0.12) : "transparent"
        border.color: area.containsMouse ? (danger ? Theme.warn : Theme.accent) : Theme.muted
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.text
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: btn.danger ? Theme.warn : Theme.fg
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    // One device line: name on the left, status on the right, as the demo's .lst rows.
    component DevRow: Rectangle {
        id: dev
        property var device
        property string status
        property bool on: false
        signal clicked()
        width: parent ? parent.width : 0
        height: 32
        color: devArea.containsMouse ? Ui.alpha(Theme.accent, 0.10) : "transparent"
        border.color: on ? Theme.accent : "transparent"
        Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusText.implicitWidth - 32
            elide: Text.ElideRight
            text: dev.device ? (dev.device.name || dev.device.deviceName || dev.device.address) : ""
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: dev.on ? Theme.fg : Theme.dim
        }
        Text {
            id: statusText
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: dev.status
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
        MouseArea { id: devArea; anchors.fill: parent; hoverEnabled: true; onClicked: dev.clicked() }
    }

    component Hint: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        font { family: Theme.fontFamily; pixelSize: 11 }
        color: Theme.dim
    }

    SetCard {
        title: "bluetooth"
        Hint { visible: !page.adapter; text: "no bluetooth adapter found (is bluetooth.service running?)" }
        SetRow {
            visible: !!page.adapter
            label: "bluetooth"
            SetSeg {
                width: parent.width
                options: [[true, "on"], [false, "off"]]
                value: page.on
                onPicked: v => { if (page.adapter) page.adapter.enabled = v }
            }
        }
        SetRow {
            visible: page.on
            label: "visible to others"
            SetSeg {
                width: parent.width
                options: [[true, "on"], [false, "off"]]
                value: page.on && page.adapter.discoverable
                onPicked: v => page.adapter.discoverable = v
            }
        }
        Hint {
            visible: !!page.adapter && !page.on
            text: page.adapter && page.adapter.state === BluetoothAdapterState.Blocked
                ? "bluetooth is blocked (rfkill unblock bluetooth)" : "bluetooth is off"
        }
    }

    SetCard {
        visible: page.on
        title: "my devices"
        Repeater {
            model: page.known
            DevRow {
                required property var modelData
                device: modelData
                status: page.statusOf(modelData)
                on: modelData === page.sel
                onClicked: page.selected = modelData.address
            }
        }
        Hint { visible: page.known.length === 0; text: "no paired devices" }
        Flow {  // actions for the selected device
            visible: !!page.sel
            width: parent.width
            spacing: 6
            Btn {
                text: page.sel && page.sel.connected ? "disconnect" : "connect"
                onClicked: page.sel.connected ? page.sel.disconnect() : page.sel.connect()
            }
            Btn {
                text: page.sel && page.sel.trusted ? "untrust" : "trust"
                onClicked: page.sel.trusted = !page.sel.trusted
            }
            Btn { text: "forget"; danger: true; onClicked: { page.sel.forget(); page.selected = "" } }
        }
    }

    SetCard {
        visible: page.on
        title: "new devices"
        action: page.adapter && page.adapter.discovering ? "stop" : "scan"
        onActionClicked: page.scan(!page.adapter.discovering)
        Repeater {
            model: page.adapter && (page.adapter.discovering || page.scanned) ? page.found : []
            DevRow {
                required property var modelData
                device: modelData
                status: page.kindOf(modelData) + " · " + (modelData.pairing ? "pairing… (click to cancel)" : "pair")
                on: modelData === page.pairing
                onClicked: modelData.pairing ? modelData.cancelPair() : page.pair(modelData)
            }
        }
        Hint {
            visible: !(page.adapter && (page.adapter.discovering || page.scanned)) || page.found.length === 0
            text: page.adapter && page.adapter.discovering ? "looking for devices…"
                : page.scanned ? "nothing new found" : "scan to find devices in pairing mode"
        }
    }
}
