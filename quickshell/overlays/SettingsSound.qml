import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../common"
import "../panel"
import "Ui.js" as Ui

// Settings > Sound, from PipeWire:
//   out  volume and balance of the output in use, a test sound, the list of outputs (click one
//        to use it) and openTHX (openthx-ctl: spatial on / off, open the window)
//   inp  the same for microphones, a live input level (pw-record) and noise suppression (an
//        rnnoise filter-chain in ~/.config/pipewire/pipewire.conf.d; needs noise-suppression-for-voice)
//   mix  a volume slider per app that is playing
Column {
    id: page
    property string kind: "out"
    spacing: 12

    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var devices: audioNodes.filter(n => !n.isStream && n.isSink === (kind === "out"))
    readonly property var streams: audioNodes.filter(n => n.isStream && !n.isSink)
    readonly property var current: kind === "inp" ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink

    // ---- balance: from the front left / right channel volumes; 50 is centre
    readonly property var chans: current && current.audio ? current.audio.channels : []
    readonly property int li: chans.indexOf(PwAudioChannel.FrontLeft)
    readonly property int ri: chans.indexOf(PwAudioChannel.FrontRight)
    readonly property bool hasBalance: li >= 0 && ri >= 0
    readonly property real balance: {
        if (!hasBalance) return 50
        const v = current.audio.volumes, l = v[li], r = v[ri]
        if (l === r) return 50
        return r < l ? 50 * r / l : 100 - 50 * l / r
    }
    function setBalance(b) {
        if (!hasBalance) return
        const v = current.audio.volumes.slice(), top = Math.max(v[li], v[ri])
        v[li] = top * Math.min(1, (100 - b) / 50)
        v[ri] = top * Math.min(1, b / 50)
        current.audio.volumes = v
    }
    function balanceText(b) {
        b = Math.round(b)
        return b === 50 ? "centre" : b < 50 ? "L " + (50 - b) * 2 + "%" : "R " + (b - 50) * 2 + "%"
    }

    // ---- openTHX: `openthx-ctl bar` gives {text, tooltip, class}; class off = engine not running,
    // bypass = spatial off. Empty when openthx-ctl is not installed.
    readonly property string thxCtl: "c=$(command -v openthx-ctl || echo \"$HOME/.local/bin/openthx-ctl\"); [ -x \"$c\" ] || exit 0; "
    property string thxClass: ""
    property string thxTip: ""
    Process {
        id: thxPoll
        running: page.kind === "out"
        command: ["sh", "-c", page.thxCtl + "exec \"$c\" bar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text)
                    page.thxClass = j["class"] || "on"
                    page.thxTip = (j.tooltip || "").split("\n")[0]
                } catch (e) {
                    page.thxClass = ""
                }
            }
        }
    }
    Timer { id: thxRefresh; interval: 600; onTriggered: thxPoll.running = true }

    // ---- input level: peak of the default mic, 10 times a second, while the page is open
    property int level: 0
    Process {
        running: page.kind === "inp"
        command: ["sh", "-c", "pw-record --rate 8000 --channels 1 --format s16 - 2>/dev/null | python3 -u -c \"$1\"", "sh",
            "import sys, array\n"
            + "while True:\n"
            + "    b = sys.stdin.buffer.read(1600)\n"
            + "    if len(b) < 2: break\n"
            + "    a = array.array('h', b[:len(b) // 2 * 2])\n"
            + "    print(min(100, round(max(abs(x) for x in a) / 327.67)))\n"]
        stdout: SplitParser { onRead: line => page.level = parseInt(line) || 0 }
    }

    // ---- noise suppression: on while the filter-chain file exists
    readonly property string nsFile: Quickshell.env("HOME") + "/.config/pipewire/pipewire.conf.d/99-rice-rnnoise.conf"
    property bool nsOn: false
    readonly property string nsConf: "# Written by the rice settings window (Sound > Input): an rnnoise-filtered mic.\n"
        + "context.modules = [\n{ name = libpipewire-module-filter-chain\n  args = {\n"
        + "    node.description = \"Noise suppressed mic\"\n    media.name = \"Noise suppressed mic\"\n"
        + "    filter.graph = { nodes = [ { type = ladspa name = rnnoise plugin = /usr/lib/ladspa/librnnoise_ladspa.so\n"
        + "        label = noise_suppressor_mono control = { \"VAD Threshold (%)\" = 50.0 } } ] }\n"
        + "    capture.props = { node.name = \"capture.rice_rnnoise\" node.passive = true audio.rate = 48000 }\n"
        + "    playback.props = { node.name = \"rice_rnnoise\" media.class = Audio/Source audio.rate = 48000 }\n  }\n}\n]\n"
    Process {
        running: page.kind === "inp"
        command: ["test", "-e", page.nsFile]
        onExited: code => page.nsOn = code === 0
    }
    function setNoise(on) {
        nsOn = on
        const write = on ? "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"" : "rm -f \"$2\""
        Quickshell.execDetached(["sh", "-c", write + "; systemctl --user restart pipewire pipewire-pulse wireplumber",
            "sh", nsConf, nsFile])
        if (on) nsPick.restart()
    }
    // once PipeWire is back, make the filtered mic the input
    Timer {
        id: nsPick
        interval: 3000
        onTriggered: {
            const n = Pipewire.nodes.values.find(x => x.name === "rice_rnnoise")
            if (n) Pipewire.preferredDefaultAudioSource = n
        }
    }

    function nameOf(n) { return n ? (n.isStream ? (n.description || n.nickname || n.name) : Sys.deviceName(n)) : "" }
    function appName(n) { return (n.properties && n.properties["application.name"]) || nameOf(n) }

    // Volume and mute are only live on nodes that are tracked.
    PwObjectTracker { objects: page.kind === "mix" ? page.streams : page.devices }

    // One volume row: slider, value, mute toggle.
    component VolumeRow: SetRow {
        id: vrow
        property var node
        Item {
            width: parent.width
            height: 22
            Slider {
                anchors { left: parent.left; right: pct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                from: 0; to: 100; step: 1
                value: vrow.node && vrow.node.audio ? vrow.node.audio.volume * 100 : 0
                onMoved: v => { if (vrow.node && vrow.node.audio) vrow.node.audio.volume = Math.round(v) / 100 }
            }
            Text {
                id: pct
                anchors { right: mute.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: 40
                horizontalAlignment: Text.AlignRight
                text: vrow.node && vrow.node.audio ? Math.round(vrow.node.audio.volume * 100) + "%" : "–"
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.fg
            }
            Rectangle {
                id: mute
                readonly property bool on: vrow.node && vrow.node.audio ? vrow.node.audio.muted : false
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: muteText.implicitWidth + 16
                height: 22
                color: on ? Theme.accent : "transparent"
                border.color: on || muteArea.containsMouse ? Theme.accent : Theme.muted
                Text { id: muteText; anchors.centerIn: parent; text: "mute"; font { family: Theme.fontFamily; pixelSize: 12 } color: parent.on ? Theme.bg : Theme.fg }
                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (vrow.node && vrow.node.audio) vrow.node.audio.muted = !vrow.node.audio.muted
                }
            }
        }
    }

    SetCard {
        visible: page.kind !== "mix"
        title: "volume"
        VolumeRow { label: page.kind === "inp" ? "microphone" : "level"; node: page.current }
        SetRow {
            visible: page.kind === "out" && page.hasBalance
            label: "balance"
            Item {
                width: parent.width
                height: 22
                Slider {
                    anchors { left: parent.left; right: balText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    from: 0; to: 100; step: 5
                    value: page.balance
                    onMoved: v => page.setBalance(Math.round(v))
                }
                Text {
                    id: balText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: page.balanceText(page.balance)
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.fg
                }
            }
        }
        SetRow {
            visible: page.kind === "out"
            label: "test"
            SettingsNetButton {
                text: "play test sound"
                onClicked: Quickshell.execDetached(["sh", "-c", "d=/usr/share/sounds/freedesktop/stereo; "
                    + "pw-play \"$d/audio-volume-change.oga\" 2>/dev/null || pw-play \"$d/bell.oga\""])
            }
        }
        SetRow {
            visible: page.kind === "inp"
            label: "input level"
            Rectangle {
                width: parent.width
                height: 8
                color: "transparent"
                border.color: Theme.muted
                Rectangle {
                    x: 1; y: 1
                    height: parent.height - 2
                    width: (parent.width - 2) * page.level / 100
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
        }
        SetRow {
            visible: page.kind === "inp"
            label: "noise suppression"
            Row {
                spacing: 10
                SettingsNetSwitch { on: page.nsOn; onToggled: page.setNoise(!page.nsOn) }
                Text {
                    text: "rnnoise filter · restarts PipeWire"
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: Theme.dim
                }
            }
        }
    }

    SetCard {
        visible: page.kind === "out" && page.thxClass !== ""
        title: "openTHX spatial"
        SetRow {
            label: "spatial"
            Row {
                spacing: 10
                SettingsNetSwitch {
                    on: page.thxClass !== "off" && page.thxClass !== "bypass"
                    enabled: page.thxClass !== "off"
                    onToggled: { Quickshell.execDetached(["sh", "-c", page.thxCtl + "exec \"$c\" toggle"]); thxRefresh.restart() }
                }
                Text {
                    text: page.thxClass === "off" ? "engine not running" : page.thxTip
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: Theme.dim
                }
            }
        }
        SetRow {
            label: "window"
            SettingsNetButton {
                text: "open openTHX"
                onClicked: Quickshell.execDetached(["sh", "-c", "command -v openthx >/dev/null && exec openthx || exec gtk-launch openthx"])
            }
        }
    }

    SetCard {
        visible: page.kind !== "mix"
        title: page.kind === "inp" ? "input" : "output"
        Repeater {
            model: page.devices
            Rectangle {
                required property var modelData
                readonly property bool on: modelData === page.current
                width: parent.width
                height: 32
                color: area.containsMouse ? Ui.alpha(Theme.accent, 0.10) : "transparent"
                border.color: on ? Theme.accent : "transparent"
                Text {
                    x: 8
                    width: parent.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: page.nameOf(parent.modelData)
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: parent.on ? Theme.fg : Theme.dim
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (page.kind === "inp") Pipewire.preferredDefaultAudioSource = parent.modelData
                        else Pipewire.preferredDefaultAudioSink = parent.modelData
                    }
                }
            }
        }
        Text {
            visible: page.devices.length === 0
            text: "no devices"
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.dim
        }
    }

    SetCard {
        visible: page.kind === "mix"
        title: "apps playing"
        Repeater {
            model: page.streams
            VolumeRow { required property var modelData; label: page.appName(modelData); node: modelData }
        }
        Text {
            visible: page.streams.length === 0
            text: "no app is playing sound"
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.dim
        }
    }
}
