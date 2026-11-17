import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Quick panel, deck tab: a grid of one-press buttons, as in the demo. Each button runs the
// command for its key in ~/.config/rice/deck.conf (`key: command`). The four toggles also have
// a `key?: command` line whose exit status says whether they are on; it is checked every two
// seconds while the tab is open, and right after a press.
Column {
    id: root

    spacing: 10

    readonly property string file: Quickshell.env("HOME") + "/.config/rice/deck.conf"
    // [key, label, toggle, icon]: icon paths from the demo (24 x 24 grid)
    readonly property var buttons: [
        ["shot", "screenshot", false, "M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4M9 12h6M12 9v6"],
        ["rec", "record", true, "M12 5a7 7 0 1 0 0 14a7 7 0 1 0 0-14zM12 10a2 2 0 1 0 0 4a2 2 0 1 0 0-4z"],
        ["pick", "colour picker", false, "M14 4l6 6M5 19l1-4 9-9 3 3-9 9zM12 7l5 5"],
        ["term", "terminal", false, "M3 5h18v14H3zM7 9l3 3-3 3M12 15h5"],
        ["files", "files", false, "M3 6h6l2 2h10v11H3z"],
        ["web", "browser", false, "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"],
        ["mic", "mute mic", true, "M9 3h6v11H9zM5 11a7 7 0 0 0 14 0M12 18v3"],
        ["game", "game mode", true, "M6 8h12a4 4 0 0 1 4 4v1a3 3 0 0 1-5.5 1.7L15 13H9l-1.5 1.7A3 3 0 0 1 2 13v-1a4 4 0 0 1 4-4zM7 10v3M5.5 11.5h3M16 11h.01M18 13h.01"],
        ["clip", "clipboard", false, "M9 3h6v3H9zM7 5H5v16h14V5h-2M8 11h8M8 15h6"],
        ["emoji", "emoji", false, "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM9 10h.01M15 10h.01M8.5 14a4 4 0 0 0 7 0"],
        ["calc", "calculator", false, "M6 3h12v18H6zM9 7h6M9 11h.01M12 11h.01M15 11h.01M9 15h.01M12 15h.01M15 15h.01M9 18h.01M12 18h.01M15 18h.01"],
        ["cup", "stay awake", true, "M5 9h11v5a5 5 0 0 1-10 0zM16 10h2a2 2 0 0 1 0 4h-2M8 3v3M12 3v3"]
    ]

    property var commands: ({})   // key -> command; "key?" -> state check
    property var on: ({})         // key -> true for toggles that are on

    function parse(text) {
        const out = {};
        for (const line of text.split("\n")) {
            const m = /^\s*([a-z]+\??)\s*:\s*(.+)$/.exec(line);
            if (m)
                out[m[1]] = m[2];
        }
        commands = out;
        check();
    }

    function check() {
        if (checker.running)
            return;
        const args = [];
        for (const b of buttons)
            if (b[2] && commands[b[0] + "?"])
                args.push(b[0], commands[b[0] + "?"]);
        checker.command = ["sh", "-c", "while [ $# -gt 1 ]; do sh -c \"$2\" >/dev/null 2>&1 && echo \"$1\"; shift 2; done", "sh"].concat(args);
        checker.running = true;
    }

    function press(key) {
        const c = commands[key];
        if (!c)
            return;
        Quickshell.execDetached(["sh", "-c", c]);
        if (buttons.find(b => b[0] === key)[2])
            recheck.restart();
    }

    FileView {
        path: root.file
        watchChanges: true
        printErrors: false   // missing: the buttons do nothing and the hint says why
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.commands = {}
    }

    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const k of this.text.split("\n"))
                    if (k)
                        o[k] = true;
                root.on = o;
            }
        }
    }

    Timer {
        interval: 2000
        running: Popup.mode === "panel"
        triggeredOnStart: true
        repeat: true
        onTriggered: root.check()
    }
    Timer {
        id: blink
        property bool dark: false
        interval: 500
        running: Popup.mode === "panel" && root.on.rec === true
        repeat: true
        onTriggered: dark = !dark
    }
    Timer {
        id: recheck
        interval: 600   // let the command start or stop before asking again
        onTriggered: root.check()
    }

    Card {
        title: "deck"
        width: parent.width

        Grid {
            id: grid
            width: parent.width
            columns: 4
            spacing: 8

            Repeater {
                model: root.buttons

                Rectangle {
                    id: btn
                    required property var modelData
                    readonly property string key: modelData[0]
                    readonly property bool lit: root.on[key] === true
                    readonly property bool has: root.commands[key] !== undefined
                    property bool hit: false

                    width: (grid.width - grid.spacing * 3) / 4
                    height: 84
                    opacity: has ? 1 : 0.45
                    color: hit ? Theme.alpha(Theme.accent, 0.3) : lit ? Theme.alpha(Theme.accent, 0.16) : "transparent"
                    border.width: 1
                    border.color: lit || mouse.containsMouse ? Theme.accent : Theme.muted

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: btn.modelData[3]
                            size: 24
                            stroke: 1.7
                            color: btn.lit ? Theme.accent : Theme.fg

                            // recording: the dot blinks, as in the demo
                            opacity: btn.key === "rec" && btn.lit && blink.dark ? 0.25 : 1
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.key === "mic" && btn.lit ? "mic muted" : btn.modelData[1]
                            color: Theme.dim
                            font.pixelSize: Theme.smallSize
                        }
                    }

                    Timer {
                        id: flash
                        interval: 180
                        onTriggered: btn.hit = false
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: btn.has ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!btn.has)
                                return;
                            if (!btn.modelData[2]) {
                                btn.hit = true;
                                flash.restart();
                            }
                            root.press(btn.key);
                        }
                    }
                }
            }
        }

        Label {
            text: Object.keys(root.commands).length ? "each button runs a command from ~/.config/rice/deck.conf" : "no ~/.config/rice/deck.conf: run install.sh, or copy rice/deck.conf there"
            color: Theme.dim
            font.pixelSize: Theme.smallSize
            width: parent.width
            wrapMode: Text.Wrap
        }
    }
}
