import QtQuick
import Quickshell
import "../common"

// Quick panel, first tab: greeting and date, quick toggles with volume and brightness,
// now playing and system at a glance, power actions (hold to confirm the risky ones).
Column {
    id: root

    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function greet() {
        const h = clock.date.getHours();
        return h < 5 ? "up late" : h < 12 ? "good morning" : h < 18 ? "good afternoon" : "good evening";
    }

    Card {
        width: parent.width

        Item {
            width: parent.width
            height: Math.max(left.implicitHeight, right.implicitHeight)

            Column {
                id: left
                spacing: 6
                Label {
                    text: Qt.formatTime(clock.date, "HH:mm")
                    font.pixelSize: 30
                    font.bold: true
                }
                Label {
                    text: root.greet() + ", " + Sys.user
                    color: Theme.accent
                }
            }

            Column {
                id: right
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                Label {
                    anchors.right: parent.right
                    text: Qt.formatDate(clock.date, "dddd d MMMM")
                    color: Theme.dim
                }
                Label {
                    anchors.right: parent.right
                    text: "up " + Stats.fmtUptime(Stats.uptime)
                    color: Theme.dim
                }
            }
        }
    }

    Card {
        title: "quick"
        width: parent.width

        Grid {
            width: parent.width
            columns: 4
            spacing: 6
            bottomPadding: 4

            readonly property real cell: (width - spacing * 3) / 4

            Tile {
                width: parent.cell
                icon: Icons.wifi(3, !Sys.wifiOn)
                label: "Wi-Fi"
                sub: Sys.wifiOn ? (Sys.wifiNet ? Sys.wifiNet.name : "not connected") : "off"
                on: Sys.wifiOn
                onClicked: Sys.toggleWifi()
            }
            Tile {
                width: parent.cell
                icon: Icons.bt + (Sys.btOn ? "" : Icons.slash)
                label: "Bluetooth"
                sub: Sys.btName
                on: Sys.btOn
                onClicked: Sys.toggleBt()
            }
            Tile {
                width: parent.cell
                icon: Icons.moon
                label: "Focus"
                sub: Notifs.dnd ? "no alerts" : "off"
                on: Notifs.dnd
                onClicked: Notifs.toggleDnd()
            }
            Tile {
                width: parent.cell
                icon: Icons.sun
                label: "Night light"
                sub: Sys.night ? Sys.nightTemp + " K" : "off"
                on: Sys.night
                onClicked: Sys.toggleNight()
            }
        }

        RangeRow {
            width: parent.width
            label: "volume"
            value: Sys.volume
            valueText: Sys.muted ? "muted" : Sys.volume + "%"
            onMoved: v => Sys.setVolume(Math.round(v))
        }

        RangeRow {
            visible: Sys.brightness >= 0
            width: parent.width
            label: "brightness"
            value: Sys.brightness
            onMoved: v => Sys.setBrightness(Math.round(v))
        }
    }

    Row {
        width: parent.width
        spacing: 10

        readonly property real half: (width - spacing) / 2

        Card {
            title: "now playing"
            width: parent.half
            height: Math.max(implicitHeight, sysCard.implicitHeight)
            clickable: true
            onClicked: Popup.tab = "media"

            Row {
                width: parent.width
                spacing: 10

                Art {
                    width: 40
                    height: 40
                }
                Column {
                    width: parent.width - 40 - 10 - 28 - 20
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: Sys.player ? Sys.player.trackTitle : "nothing playing"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: Sys.player ? Sys.player.trackArtist : ""
                        color: Theme.dim
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Sys.player && Sys.player.isPlaying ? Icons.pause : Icons.play
                    size: 18
                    enabled: Sys.player !== null
                    onClicked: Sys.player.togglePlaying()
                }
            }
        }

        Card {
            id: sysCard
            title: "system"
            width: parent.half
            clickable: true
            onClicked: Popup.tab = "system"

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [["cpu", Stats.cpu + "%"], ["mem", Stats.mem + "%"], Stats.hasGpu && Stats.gpuTemp >= 0 ? ["gpu", Stats.gpuTemp + "°"] : ["temp", Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°" : "–"]]

                    Rectangle {
                        required property var modelData
                        width: (parent.width - 12) / 3
                        height: 42
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.muted

                        Column {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Label {
                                text: modelData[0]
                                color: Theme.dim
                                font.pixelSize: Theme.smallSize
                            }
                            Label {
                                text: modelData[1]
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 6

        readonly property real cell: (width - spacing * 4) / 5

        PowerButton {
            width: parent.cell
            icon: Icons.lock
            label: "lock"
            command: ["loginctl", "lock-session"]
        }
        PowerButton {
            width: parent.cell
            icon: Icons.sleep
            label: "sleep"
            hold: 1000
            command: ["systemctl", "suspend"]
        }
        PowerButton {
            width: parent.cell
            icon: Icons.logout
            label: "log out"
            hold: 2000
            // ends the login session; works whichever Hyprland config language is in use
            command: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]
        }
        PowerButton {
            width: parent.cell
            icon: Icons.reboot
            label: "restart"
            hold: 3000
            command: ["systemctl", "reboot"]
        }
        PowerButton {
            width: parent.cell
            icon: Icons.power
            label: "shut down"
            hold: 3000
            command: ["systemctl", "poweroff"]
        }
    }
}
