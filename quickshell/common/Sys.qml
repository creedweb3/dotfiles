pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Hyprland

// Sound, network, Bluetooth, brightness, focus mode and night light: state plus the
// small actions the bar, quick panel and OSD need.
Singleton {
    id: root

    // ---- sound (PipeWire default sink and source)
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }

    readonly property bool hasSink: sink !== null && sink.audio !== null
    readonly property int volume: hasSink ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: hasSink ? sink.audio.muted : true
    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : "no output"
    readonly property bool hasSource: source !== null && source.audio !== null
    readonly property int micVolume: hasSource ? Math.round(source.audio.volume * 100) : 0
    readonly property bool micMuted: hasSource ? source.audio.muted : true
    readonly property string sourceName: source ? (source.description || source.nickname || source.name) : "no input"

    function setVolume(percent) {
        if (!hasSink)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    function toggleMute() {
        if (hasSink)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (hasSource)
            source.audio.muted = !source.audio.muted;
    }

    // ---- network (NetworkManager through Quickshell.Networking)
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property int wifiBars: wifiNet ? (wifiNet.signalStrength > 0.66 ? 3 : wifiNet.signalStrength > 0.33 ? 2 : 1) : 0
    readonly property string netName: wifiNet ? wifiNet.name : wired ? "wired" : wifiOn ? "offline" : "off"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ---- Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property var btDevice: btAdapter ? (btAdapter.devices.values.find(d => d.connected) ?? null) : null
    readonly property string btName: !btOn ? "off" : btDevice ? (btDevice.name || btDevice.deviceName) : "on"

    function toggleBt() {
        if (btAdapter)
            btAdapter.enabled = !btAdapter.enabled;
    }

    // ---- brightness (laptops; -1 when the machine has no backlight)
    property string backlight: ""
    property int brightness: -1

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlight = text.trim()
        }
    }

    FileView {
        id: briNow
        path: root.backlight ? root.backlight + "/actual_brightness" : ""
        printErrors: false
        onLoaded: root.readBrightness()
    }

    FileView {
        id: briMax
        path: root.backlight ? root.backlight + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.readBrightness()
    }

    function readBrightness() {
        const now = parseInt(briNow.text()), max = parseInt(briMax.text());
        if (now >= 0 && max > 0)
            brightness = Math.round(now / max * 100);
    }

    // sysfs files do not raise change events, so poll; cheap (one small read).
    Timer {
        running: root.backlight !== ""
        interval: 300
        repeat: true
        onTriggered: briNow.reload()
    }

    function setBrightness(percent) {
        Quickshell.execDetached(["brightnessctl", "-q", "s", Math.max(1, Math.min(100, percent)) + "%"]);
    }

    // ---- night light (hyprsunset running = on)
    property bool night: false
    readonly property int nightTemp: 4500

    Process {
        id: nightCheck
        running: true
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => root.night = code === 0
    }

    function toggleNight() {
        if (night)
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        else
            // Settings > Night light saves warmth and schedule here; without it, a fixed warmth.
            Quickshell.execDetached(["sh", "-c",
                'f="$HOME/.config/hypr/rice-night.conf"; if [ -f "$f" ]; then exec hyprsunset -c "$f"; else exec hyprsunset -t "$1"; fi',
                "sh", String(nightTemp)]);
        night = !night;
    }

    // ---- media player (MPRIS): the one picked in the media tab's source row while it is
    // running, else the playing one, else the first
    readonly property var players: Mpris.players.values
    property string chosenPlayer: ""   // its dbusName
    readonly property MprisPlayer player: players.find(p => p.dbusName === chosenPlayer) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    function choosePlayer(p) {
        chosenPlayer = p ? p.dbusName : "";
    }

    // MPRIS position does not update by itself; nudge it once a second while a pop-up shows it.
    Timer {
        running: root.player !== null && root.player.isPlaying && Popup.mode !== ""
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- Hyprland 0.55+ (Lua config): dispatch takes an hl.dsp expression
    function goWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // ---- who
    readonly property string user: Quickshell.env("USER")
}
