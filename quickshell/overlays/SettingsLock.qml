import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../lock"

// Settings > Appearance > Lock screen: the manga lock (quickshell/lock/), as the demo's lock page.
// Everything saves to ~/.config/rice/prefs.json (Prefs) and shows in the live preview; the next lock
// uses it. Settings.qml also writes the shared options to ~/.config/hypr/rice-lock.conf, so hyprlock
// (the fallback locker) follows them as far as it can.
Column {
    id: page
    spacing: 12

    property bool fetching: false
    property string fetchResult: ""

    function on(k) { return Prefs[k] === "on" }
    function flip(k) { Prefs.set(k, on(k) ? "off" : "on") }
    function pick(k, v) { Prefs.set(k, v) }

    LockData { id: frameData }

    // new frames for the current preset: scripts/manga-frames (MangaDex), 24 pages
    Process {
        id: fetchProc
        command: ["sh", "-c",
            "m=$(command -v manga-frames || echo \"$HOME/.local/bin/manga-frames\"); " +
            "[ -x \"$m\" ] || { echo 'manga-frames is not installed'; exit 127; }; exec \"$m\" 24 \"$1\" 2>&1",
            "sh", frameData.preset]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x.trim() !== "")
                page.fetchResult = lines.length ? lines[lines.length - 1] : ""
            }
        }
        onExited: code => {
            page.fetching = false
            if (code !== 0 && page.fetchResult === "") page.fetchResult = "fetch failed (exit " + code + ")"
            frameData.refresh()
        }
    }

    // ---- live preview (the lock at 1920x1080, scaled to the page)
    Rectangle {
        width: parent.width
        height: width * 9 / 16
        color: "#111111"
        border.color: Theme.muted
        clip: true
        MangaPage {
            width: 1920
            height: 1080
            scale: (parent.width - 2) / 1920
            transformOrigin: Item.TopLeft
            x: 1; y: 1
            lockData: frameData
            shader: "file://" + Theme.cacheDir + "/ink.frag.qsb"
            now: clock.date
            typed: "• • • • "
            notifs: 2
            player: Sys.player
            interactive: false
        }
        SystemClock { id: clock; precision: SystemClock.Minutes }
    }

    SetCard {
        title: "locker"
        action: "lock now"
        onActionClicked: Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/rice-lock\""])
        SetRow {
            label: "lock with"
            pref: "locker"
            SetSeg {
                options: [["quickshell", "manga lock"], ["hyprlock", "hyprlock"]]
                value: Prefs.locker
                onPicked: v => Prefs.set("locker", v)
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "hyprlock is the plain fallback: centred clock and password, no frames, quote, notifications or music styles"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "frames"
        action: "lock timing"
        onActionClicked: Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "settings", "openPage", "power"])
        SetRow {
            label: "panels"
            pref: "mfr"
            SetSeg {
                options: [6, 8, 10, 12, 18, 24, 32, 40, 48, 56, 64, 72, 80].map(n => [n, String(n)])
                value: Prefs.mfr
                onPicked: v => page.pick("mfr", v)
            }
        }
        SetRow {
            label: "layout"
            pref: "mpg"
            SetSeg {
                options: [["random", "random"], ["grid", "grid"], ["slant", "slant"], ["diagonal", "diagonal"], ["shatter", "shatter"], ["cutoff", "cut off"]]
                value: Prefs.mpg
                onPicked: v => page.pick("mpg", v)
            }
        }
        SetRow {
            label: "pick"
            pref: "mpick"
            SetSeg {
                options: [["action", "action"], ["any", "any"]]
                value: Prefs.mpick
                onPicked: v => page.pick("mpick", v)
            }
        }
        SetRow {
            label: "new frames"
            Row {
                spacing: 10
                Rectangle {
                    width: fetchText.implicitWidth + 20
                    height: fetchText.implicitHeight + 8
                    color: "transparent"
                    border.color: fetchArea.containsMouse && !page.fetching ? Theme.accent : Theme.muted
                    opacity: page.fetching || !frameData.preset ? .5 : 1
                    Text {
                        id: fetchText
                        anchors.centerIn: parent
                        text: page.fetching ? "fetching…" : "fetch new frames"
                        font { family: Theme.fontFamily; pixelSize: 13 }
                        color: Theme.fg
                    }
                    MouseArea {
                        id: fetchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !page.fetching && frameData.preset !== ""
                        onClicked: {
                            page.fetching = true
                            page.fetchResult = ""
                            fetchProc.running = true
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.fetchResult
                    elide: Text.ElideRight
                    width: Math.max(0, page.width - 360)
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: Theme.dim
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: frameData.hasFrames
                ? frameData.frames.length + " frames for " + (frameData.info.label || frameData.preset) + " · " + frameData.store
                : "no manga frames for " + (frameData.preset || "this preset") + " yet: the lock shows the preset's wallpapers until you fetch some"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "ink"
        SetRow {
            label: "ink"
            pref: "mink"
            SetSeg {
                options: [["mono", "mono"], ["accent", "accent"], ["duo", "duo"], ["spot", "spot"], ["riso", "riso"], ["night", "night"], ["gutter", "gutter"], ["colour", "colour"]]
                value: Prefs.mink
                onPicked: v => page.pick("mink", v)
            }
        }
        SetRow {
            label: "accent"
            pref: "macc"
            SetSeg {
                options: [["full", "full"], ["soft", "soft"], ["borders", "borders"], ["panels", "panels"], ["time", "time"]]
                value: Prefs.macc
                onPicked: v => page.pick("macc", v)
            }
        }
    }

    SetCard {
        title: "shows"
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: [["mlsym", "symbol"], ["mlday", "day"], ["mldate", "date"], ["mlquote", "quote"], ["mlmusic", "music"], ["mlnotif", "notifications"], ["mlhint", "unlock hint"]]
                Rectangle {
                    required property var modelData
                    readonly property bool lit: Prefs[modelData[0]] === "on"
                    width: chipText.implicitWidth + 20
                    height: chipText.implicitHeight + 6
                    color: lit ? Theme.accent : "transparent"
                    border.color: lit || chipArea.containsMouse ? Theme.accent : Theme.muted
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData[1]
                        font { family: Theme.fontFamily; pixelSize: 13 }
                        color: parent.lit ? Theme.bg : Theme.fg
                    }
                    MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; onClicked: page.flip(parent.modelData[0]) }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "notifications shows only how many are waiting, never their text"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        visible: page.on("mlday") || page.on("mldate") || page.on("mlquote")
        title: "date and hint"
        SetRow {
            visible: page.on("mlday")
            label: "day"
            pref: "mday"
            SetSeg {
                options: [["tag", "tag"], ["plain", "plain"], ["rule", "rule"], ["kanji", "kanji"], ["mix", "rule + kanji"]]
                value: Prefs.mday
                onPicked: v => page.pick("mday", v)
            }
        }
        SetRow {
            visible: page.on("mldate")
            label: "format"
            pref: "mdt"
            SetSeg {
                options: [["long", "25 october"], ["short", "sun 25 oct"], ["num", "25.10.2026"], ["iso", "2026-10-25"]]
                value: Prefs.mdt
                onPicked: v => page.pick("mdt", v)
            }
        }
        SetRow {
            visible: page.on("mlquote")
            label: "hint line"
            pref: "mhint"
            SetSeg {
                options: [["off", "off"], ["quote", "quote"], ["chapter", "chapter"], ["rule", "rule"]]
                value: Prefs.mhint
                onPicked: v => page.pick("mhint", v)
            }
        }
    }

    SetCard {
        visible: page.on("mlmusic")
        title: "music"
        SetRow {
            label: "style"
            pref: "mmus"
            SetSeg {
                options: [["spectrum", "spectrum"], ["eq", "eq"], ["wavetick", "wave + ticker"], ["mirror", "mirror"], ["line", "line"],
                    ["ticker", "ticker"], ["wave", "wave"], ["eqtick", "eq + ticker"], ["spectick", "spectrum + ticker"],
                    ["specline", "spectrum + line"], ["wavebar", "wave bar"], ["underwave", "underwave"], ["eqline", "eq + line"]]
                value: Prefs.mmus
                onPicked: v => page.pick("mmus", v)
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "spectrum: a title too long for its row scrolls · bars follow the music through cava; prev / play / next work on the lock"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
