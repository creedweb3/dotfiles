import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../common"

// The rice's lock screen: the demo's manga lock on every screen (ext-session-lock), password checked
// by PAM with the stock "login" config, the same stack hyprlock uses.
//   qs -c rice ipc call lock lock        (scripts/rice-lock, SUPER+L, hypridle)
//   qs -c rice ipc call lock isLocked
// If Quickshell dies while locked, the screen stays locked (Hyprland's red "lockdead" screen). Recover
// from a TTY as that screen says; misc.allow_session_lock_restore stays off, because with it on any
// Wayland client may take over a live lock and unlock it.
// Live reload is off while locked: a reloaded WlSessionLock starts with locked = false and unlocks.
Scope {
    id: root

    property string buffer: ""
    property string message: ""
    property int shakeTick: 0
    // notifications in the rice's daemon (count only, nothing of their text shows on the lock)
    readonly property int notifs: Notifs.list.length
    property var spectrum: []
    // set fresh on every lock: the cut, the frame mix
    property string style: "grid"
    property int seed: 0
    property int shift: 0

    readonly property bool locked: sessionLock.locked
    readonly property bool musicOn: locked && Prefs.mlmusic === "on" && Sys.player !== null && Sys.player.isPlaying
    readonly property string inkSource: Qt.resolvedUrl("ink.frag").toString().replace(/^file:\/\//, "")
    readonly property string inkQsb: Theme.cacheDir + "/ink.frag.qsb"
    property bool inkReady: false

    function lock() {
        if (sessionLock.locked) return
        frameData.refresh()
        const rs = Prefs.mpg === "random"
        style = rs ? ["grid", "slant", "diagonal", "shatter", "cutoff"][Math.floor(Math.random() * 5)] : Prefs.mpg
        seed = rs ? Math.floor(Math.random() * 1e6) : 0
        shift = Math.floor(Math.random() * 100000)
        buffer = ""
        message = ""
        sessionLock.locked = true
    }
    function submit() {
        if (pam.active || buffer === "") return
        message = ""
        if (!pam.start()) {
            message = "could not start the password check"
            shakeTick++
        }
    }
    function key(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) submit()
        else if (event.key === Qt.Key_Backspace) buffer = buffer.slice(0, -1)
        else if (event.key === Qt.Key_Escape) buffer = ""
        else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !pam.active) buffer += event.text
        else return
        event.accepted = true
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return sessionLock.locked }
    }

    LockData { id: frameData }

    // No config reload while locked (see the header): file changes are ignored until unlock.
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: !sessionLock.locked
    }

    PamContext {
        id: pam
        // config "login" in /etc/pam.d (the default), as hyprlock's own pam file includes it
        // pamMessage fires for every prompt; responseRequiredChanged does not when two prompts in a row want answers
        onPamMessage: {
            if (messageIsError) root.message = message
            if (responseRequired) respond(root.buffer)
        }
        onCompleted: result => {
            root.buffer = ""
            if (result === PamResult.Success) {
                root.message = ""
                sessionLock.locked = false
                return
            }
            root.message = result === PamResult.MaxTries ? "too many tries · wait a moment" : (root.message || "wrong password")
            root.shakeTick++
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: "#111111"

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => root.key(event)

                MangaPage {
                    anchors.fill: parent
                    lockData: frameData
                    style: root.style
                    seed: root.seed
                    shift: root.shift
                    shader: root.inkReady ? "file://" + root.inkQsb : ""
                    now: clock.date
                    typed: "• ".repeat(root.buffer.length)
                    message: root.message
                    shakeTick: root.shakeTick
                    notifs: root.notifs
                    spectrum: root.spectrum
                    player: Sys.player
                }
            }
        }
    }

    SystemClock {
        id: clock
        enabled: sessionLock.locked
        precision: SystemClock.Minutes
    }


    // ---- music bars: cava's raw output while locked and playing; a gentle fake when cava is missing
    readonly property bool barsWanted: musicOn && ["eq", "spectrum", "eqtick", "spectick", "specline", "mirror", "eqline"].indexOf(Prefs.mmus) >= 0
    readonly property string cavaConf: Theme.cacheDir + "/cava-lock.conf"
    property bool cavaOk: false   // set by cavaCheck

    FileView {
        id: cavaFile
        path: root.cavaConf
        printErrors: false
    }
    Component.onCompleted: {
        cavaFile.setText("# Written by the rice lock screen (quickshell/lock/Lock.qml).\n" +
            "[general]\nbars = 40\nframerate = 30\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\n" +
            "bar_delimiter = 59\nframe_delimiter = 10\n")
        inkProc.running = true
        cavaCheck.running = true
    }

    Process {
        id: cavaCheck
        command: ["sh", "-c", "command -v cava"]
        onExited: code => root.cavaOk = code === 0
    }

    Process {
        id: cava
        running: root.barsWanted && root.cavaOk
        command: ["cava", "-p", root.cavaConf]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 100)
                if (v.length >= 40) root.spectrum = v
            }
        }
        onExited: code => { if (code !== 0 && root.barsWanted) root.cavaOk = false }
    }
    Timer {   // without cava: each bar breathes at its own speed
        running: root.barsWanted && !root.cavaOk
        interval: 90
        repeat: true
        property real t: 0
        onTriggered: {
            t += interval / 1000
            const v = []
            for (let i = 0; i < 40; i++) {
                const h = .35 + .65 * Math.sin(Math.PI * (i + .5) / 40)
                const sp = .45 + (i * 37 % 9) / 14
                v.push(h * (.25 + .75 * Math.abs(Math.sin(t * Math.PI / sp + i * .17 * Math.PI))))
            }
            root.spectrum = v
        }
    }
    onBarsWantedChanged: if (!barsWanted) spectrum = []

    // ---- ink shader: compiled once (and after edits) with qsb from qt6-shadertools
    Process {
        id: inkProc
        command: ["sh", "-c",
            "[ \"$2\" -nt \"$1\" ] && exit 0; q=$(command -v qsb || echo /usr/lib/qt6/bin/qsb); " +
            "[ -x \"$q\" ] || exit 1; mkdir -p \"$(dirname \"$2\")\" && \"$q\" --qt6 -o \"$2\" \"$1\"",
            "sh", root.inkSource, root.inkQsb]
        onExited: code => {
            root.inkReady = code === 0
            if (code !== 0) console.warn("lock: ink shader not compiled (install qt6-shadertools); panels print in plain grey")
        }
    }
}
