import QtQuick
import "../common"

// Quick panel, system tab: CPU with history and per-thread bars, memory, GPU (nvidia-smi or
// amdgpu), disks, network, and uptime / kernel / load. Bars turn amber at 85% and red at 95%.
// Click a card for its detail view (Stats.view), as in the demo; ‹ goes back.
Column {
    id: root

    spacing: 10

    component Big: Row {
        id: big
        property string value
        property string note
        spacing: 8
        Label {
            id: bigValue
            text: big.value
            font.pixelSize: 20
            font.bold: true
        }
        Label {
            anchors.baseline: bigValue.baseline
            text: big.note
            color: Theme.dim
        }
    }

    component Meter: Rectangle {
        id: meter
        property real pc: 0
        width: parent.width
        height: 6
        color: Theme.alpha(Theme.muted, 0.7)
        GraphFill {  // style and strength: Settings > Graphs
            readonly property bool high: meter.pc >= 85
            width: meter.width * Math.max(0, Math.min(100, meter.pc)) / 100
            height: meter.height
            color: meter.pc >= 95 ? Theme.crit : high ? Theme.warn : Theme.accent
            color2: high ? color : Theme.accent2
        }
    }

    component KV: Item {
        id: kv
        property string key
        property string value
        width: parent.width
        height: 18
        Label {
            text: kv.key
            color: Theme.dim
        }
        Label {
            anchors.right: parent.right
            text: kv.value
        }
    }

    component Rows: Repeater {   // [[name, value]] as KV rows
        KV {
            required property var modelData
            key: modelData[0]
            value: modelData[1]
        }
    }

    // ---- overview
    Column {
        visible: Stats.view === ""
        width: parent.width
        spacing: 10

        Card {
            title: "cpu" + (Stats.cpuName ? " · " + Stats.cpuName : "")
            width: parent.width
            clickable: true
            onClicked: Stats.view = "cpu"

            Big {
                value: Stats.cpu + "%"
                note: (Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°C · " : "") + Stats.threads + " threads"
            }
            Spark {
                width: parent.width
                values: Stats.cpuHist
            }
            // one bar per thread
            Row {
                id: coreRow
                width: parent.width
                height: 22
                spacing: 2
                Repeater {
                    model: Stats.cores
                    Rectangle {
                        required property var modelData
                        width: Math.max(1, (coreRow.width - coreRow.spacing * (Stats.cores.length - 1)) / Math.max(1, Stats.cores.length))
                        height: coreRow.height
                        color: Theme.alpha(Theme.muted, 0.5)
                        GraphFill {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(1, parent.height * Math.min(100, parent.modelData) / 100)
                            color: Theme.accent
                            color2: Theme.accent2
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            readonly property real half: (width - spacing) / 2

            Card {
                title: "memory"
                clickable: true
                onClicked: Stats.view = "mem"
                width: parent.half
                height: Math.max(implicitHeight, gpuCard.implicitHeight)

                Big {
                    value: Stats.memUsed.toFixed(1)
                    note: "/ " + Stats.memTotal.toFixed(1) + " GiB"
                }
                Meter {
                    pc: Stats.mem
                }
                KV {
                    key: "swap"
                    value: Stats.swapUsed.toFixed(1) + " / " + Stats.swapTotal.toFixed(1) + " GiB"
                }
            }

            Card {
                id: gpuCard
                clickable: true
                onClicked: Stats.view = "gpu"
                title: Stats.hasGpu ? "gpu" + (Stats.gpuName ? " · " + Stats.gpuName : "") : "gpu"
                width: parent.half

                Big {
                    value: Stats.hasGpu ? Stats.gpu + "%" : "–"
                    note: !Stats.hasGpu ? "no nvidia-smi or amdgpu" : Stats.gpuTemp >= 0 ? Stats.gpuTemp + "°C" : ""
                }
                Meter {
                    pc: Stats.gpu
                }
                KV {
                    key: "vram"
                    value: Stats.vramUsed.toFixed(1) + " / " + Stats.vramTotal.toFixed(1) + " GiB"
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            readonly property real half: (width - spacing) / 2

            Card {
                title: "disks"
                clickable: true
                onClicked: Stats.view = "disk"
                width: parent.half
                height: Math.max(implicitHeight, netCard.implicitHeight)

                Repeater {
                    model: Stats.disks

                    Column {
                        required property var modelData
                        readonly property real pc: modelData.size > 0 ? modelData.used / modelData.size * 100 : 0
                        width: parent.width
                        spacing: 4

                        KV {
                            key: modelData.mount
                            value: Math.round(modelData.used) + " / " + Math.round(modelData.size) + " GiB"
                        }
                        Meter {
                            pc: parent.pc
                        }
                    }
                }
            }

            Card {
                id: netCard
                clickable: true
                onClicked: Stats.view = "net"
                title: "network · " + Sys.netName
                width: parent.half

                KV {
                    key: "down"
                    value: Stats.down.toFixed(1) + " MB/s"
                }
                KV {
                    key: "up"
                    value: Stats.up.toFixed(1) + " MB/s"
                }
                Spark {
                    width: parent.width
                    implicitHeight: 30
                    values: Stats.netHist
                    max: 0
                }
            }
        }

        Item {
            width: parent.width
            height: 18

            Label {
                text: "up " + Stats.fmtUptime(Stats.uptime)
                color: Theme.dim
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "linux " + Stats.kernel + " · hyprland"
                color: Theme.dim
            }
            Label {
                anchors.right: parent.right
                text: "load " + Stats.load
                color: Theme.dim
            }
        }
    }

    // ---- detail view of one card
    Column {
        visible: Stats.view !== ""
        width: parent.width
        spacing: 10

        // ‹ title
        Row {
            spacing: 10
            Label {
                text: "‹"
                font.pixelSize: 20
                color: back.containsMouse ? Theme.accent : Theme.dim
                MouseArea {
                    id: back
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stats.view = ""
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                font.bold: true
                text: ({cpu: "cpu" + (Stats.cpuName ? " · " + Stats.cpuName : ""),
                        mem: "memory · " + Stats.memTotal.toFixed(1) + " GiB",
                        gpu: "gpu" + (Stats.gpuName ? " · " + Stats.gpuName : ""),
                        disk: "disks",
                        net: "network · " + Sys.netName})[Stats.view] || ""
            }
        }

        // cpu: every thread with its load and clock, then the busiest programs
        Card {
            visible: Stats.view === "cpu"
            title: "threads"
            width: parent.width
            Grid {
                id: thr
                width: parent.width
                columns: 2
                columnSpacing: 14
                rowSpacing: 4
                Repeater {
                    model: Stats.view === "cpu" ? Stats.cores : []
                    Row {
                        required property var modelData
                        required property int index
                        width: (thr.width - thr.columnSpacing) / 2
                        spacing: 6
                        Label {
                            width: 28
                            text: "C" + index
                            color: Theme.dim
                            font.pixelSize: Theme.smallSize
                        }
                        Meter {
                            width: parent.width - 28 - 34 - 56 - parent.spacing * 3
                            anchors.verticalCenter: parent.verticalCenter
                            pc: modelData
                        }
                        Label {
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: modelData + "%"
                            font.pixelSize: Theme.smallSize
                        }
                        Label {
                            width: 56
                            horizontalAlignment: Text.AlignRight
                            readonly property real mhz: Stats.coreMHz[index] || 0
                            text: mhz > 0 ? (mhz / 1000).toFixed(1) + " GHz" : ""
                            color: Theme.dim
                            font.pixelSize: Theme.smallSize
                        }
                    }
                }
            }
        }
        Card {
            visible: Stats.view === "cpu"
            title: "top processes"
            width: parent.width
            Rows {
                model: Stats.view === "cpu" ? Stats.topCpu : []
            }
        }

        // memory: used / cache / free in one bar, then the biggest programs
        Card {
            visible: Stats.view === "mem"
            title: "breakdown"
            width: parent.width
            Row {
                id: mbar
                width: parent.width
                height: 10
                readonly property real used: Stats.memTotal > 0 ? Stats.memUsed / Stats.memTotal : 0
                readonly property real cache: Stats.memTotal > 0 ? Math.min(1 - used, Stats.memCache / Stats.memTotal) : 0
                Rectangle { width: mbar.width * mbar.used; height: mbar.height; color: Theme.accent }
                Rectangle { width: mbar.width * mbar.cache; height: mbar.height; color: Theme.alpha(Theme.accent, 0.4) }
                Rectangle { width: mbar.width * Math.max(0, 1 - mbar.used - mbar.cache); height: mbar.height; color: Theme.muted }
            }
            Row {
                spacing: 14
                Repeater {
                    model: [[Theme.accent, "used " + Stats.memUsed.toFixed(1) + " GiB"],
                            [Theme.alpha(Theme.accent, 0.4), "cache " + Stats.memCache.toFixed(1) + " GiB"],
                            [Theme.muted, "free"]]
                    Row {
                        required property var modelData
                        spacing: 5
                        Rectangle { width: 8; height: 8; anchors.verticalCenter: parent.verticalCenter; color: parent.modelData[0] }
                        Label { text: parent.modelData[1]; color: Theme.dim; font.pixelSize: Theme.smallSize }
                    }
                }
            }
            KV {
                key: "swap"
                value: Stats.swapUsed.toFixed(1) + " / " + Stats.swapTotal.toFixed(1) + " GiB"
            }
        }
        Card {
            visible: Stats.view === "mem"
            title: "biggest programs"
            width: parent.width
            Rows {
                model: Stats.view === "mem" ? Stats.topMem : []
            }
        }

        // gpu: what nvidia-smi or amdgpu reports; unknown values are left out
        Card {
            visible: Stats.view === "gpu"
            title: "now"
            width: parent.width
            KV { key: "usage"; value: Stats.hasGpu ? Stats.gpu + "%" : "–" }
            KV { visible: Stats.gpuTemp >= 0; key: "temperature"; value: Stats.gpuTemp + "°C" }
            KV { visible: Stats.gpuFan >= 0; key: "fan"; value: Stats.gpuFan + "%" }
            KV {
                visible: Stats.gpuPower >= 0
                key: "power"
                value: Math.round(Stats.gpuPower) + (Stats.gpuPowerMax > 0 ? " / " + Math.round(Stats.gpuPowerMax) : "") + " W"
            }
            KV { visible: Stats.gpuClock > 0; key: "clock"; value: Stats.gpuClock + " MHz" }
            KV { key: "vram"; value: Stats.vramUsed.toFixed(1) + " / " + Stats.vramTotal.toFixed(1) + " GiB" }
            Meter { pc: Stats.vramTotal > 0 ? Stats.vramUsed / Stats.vramTotal * 100 : 0 }
        }

        // disks: every mount, then the largest folders in ~ (measured when this view opens)
        Card {
            visible: Stats.view === "disk"
            title: "mounts"
            width: parent.width
            Repeater {
                model: Stats.disks
                Column {
                    required property var modelData
                    readonly property real pc: modelData.size > 0 ? modelData.used / modelData.size * 100 : 0
                    width: parent.width
                    spacing: 4
                    KV {
                        key: modelData.mount
                        value: Math.round(modelData.used) + " / " + Math.round(modelData.size) + " GiB"
                    }
                    Meter { pc: parent.pc }
                    Label {
                        visible: parent.pc >= 85
                        text: Math.round(parent.modelData.size - parent.modelData.used) + " GiB left"
                        color: parent.pc >= 95 ? Theme.crit : Theme.warn
                        font.pixelSize: Theme.smallSize
                    }
                }
            }
        }
        Card {
            visible: Stats.view === "disk"
            title: "largest in ~"
            width: parent.width
            Label {
                visible: Stats.measuring
                text: "measuring…"
                color: Theme.dim
            }
            Rows {
                model: Stats.view === "disk" && !Stats.measuring ? Stats.bigDirs : []
            }
        }

        // network: the connection, then live speed (per-program traffic needs root, so it is left out)
        Card {
            visible: Stats.view === "net"
            title: "connection"
            width: parent.width
            KV { key: "interface"; value: Stats.netInfo.iface || "–" }
            KV { key: "ip"; value: Stats.netInfo.ip || "–" }
            KV {
                visible: Sys.wifiNet !== null
                key: "signal"
                value: Sys.wifiNet ? Math.round(Sys.wifiNet.signalStrength * 100) + "%" : ""
            }
        }
        Card {
            visible: Stats.view === "net"
            title: "live"
            width: parent.width
            KV { key: "down"; value: Stats.down.toFixed(1) + " MB/s" }
            KV { key: "up"; value: Stats.up.toFixed(1) + " MB/s" }
            Spark {
                width: parent.width
                values: Stats.netHist
                max: 0
            }
        }
    }
}
