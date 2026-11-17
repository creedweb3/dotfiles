import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"
import "../panel"
import "Ui.js" as Ui

// Settings > Display > Monitor: mode, scale, rotation, adaptive sync and placement per monitor,
// plus brightness. Saved to ~/.config/hypr/rice-monitors.lua, which hyprland.lua passes to
// hl.monitor, and shown at once with `hyprctl reload`. A change reverts by itself after 15 s
// unless it is kept, so a mode the screen cannot show never sticks.
Column {
    id: page
    spacing: 12

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-monitors.lua"
    property var mons: []          // hyprctl -j monitors all
    property string sel: ""
    property var rules: ({})       // output -> {mode, position, scale, transform, vrr}, as in the file
    property string fileText: ""   // the file as last read or written
    property string undoText: ""   // the file before the change that waits to be kept
    property int countdown: 0      // seconds left to keep a change; 0 = nothing pending

    readonly property var cur: mons.find(m => m.name === sel) || (mons.length ? mons[0] : null)
    readonly property var rule: cur ? ruleFor(cur) : null
    // "2560x1440@164.96" strings, from the monitor's own list.
    readonly property var modes: cur ? uniq((cur.availableModes || []).map(s => String(s).replace(/Hz$/, ""))) : []
    readonly property string curRes: rule ? rule.mode.split("@")[0] : ""
    readonly property var resolutions: uniq(modes.map(m => m.split("@")[0]))
        .sort((a, b) => pixels(b) - pixels(a)).slice(0, 8)
    readonly property var rates: modes.filter(m => m.split("@")[0] === curRes).map(m => m.split("@")[1])
        .sort((a, b) => parseFloat(b) - parseFloat(a))

    function uniq(list) { return list.filter((x, i) => list.indexOf(x) === i) }
    function pixels(res) { const p = res.split("x"); return (parseInt(p[0]) || 0) * (parseInt(p[1]) || 0) }
    function hz(r) { const f = parseFloat(r); return (Math.abs(f - Math.round(f)) < 0.05 ? Math.round(f) : f.toFixed(2)) + " Hz" }

    // What the monitor runs now, as a rule; used until the file has an entry for it.
    function ruleFor(m) {
        return rules[m.name] || {
            mode: m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
            position: "auto",
            scale: String(Math.round(m.scale * 100) / 100),
            transform: m.transform || 0,
            vrr: m.vrr ? 1 : 0
        }
    }

    function render(rs) {
        // Monitor names and modes are plain ASCII, so JSON quoting is valid Lua.
        const q = s => JSON.stringify(String(s))
        let out = "-- Written by the rice settings window (Display > Monitor). hyprland.lua passes each entry to hl.monitor.\nreturn {\n"
        for (const name of Object.keys(rs)) {
            const r = rs[name]
            out += "    { output = " + q(name) + ", mode = " + q(r.mode) + ", position = " + q(r.position)
                + ", scale = " + q(r.scale) + ", transform = " + parseInt(r.transform) + ", vrr = " + parseInt(r.vrr) + " },\n"
        }
        return out + "}\n"
    }
    function parse(t) {
        const out = {}
        const re = /\{\s*output\s*=\s*"([^"]*)"\s*,\s*mode\s*=\s*"([^"]*)"\s*,\s*position\s*=\s*"([^"]*)"\s*,\s*scale\s*=\s*"([^"]*)"\s*,\s*transform\s*=\s*(\d+)\s*,\s*vrr\s*=\s*(\d+)\s*\}/g
        let m
        while ((m = re.exec(t)) !== null)
            out[m[1]] = {mode: m[2], position: m[3], scale: m[4], transform: parseInt(m[5]), vrr: parseInt(m[6])}
        return out
    }
    // Write and reload in a detached shell, so a revert still lands if the settings window closes.
    function write(text) {
        fileText = text
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && hyprctl reload >/dev/null", "sh", text, file])
        refreshTimer.restart()
    }

    function change(key, value) {
        if (!cur) return
        const r = Object.assign({}, ruleFor(cur))
        r[key] = value
        const next = Object.assign({}, rules)
        next[cur.name] = r
        if (countdown === 0) undoText = fileText
        rules = next
        write(render(next))
        countdown = 15
    }
    function keep() { countdown = 0 }
    function revert() {
        countdown = 0
        rules = parse(undoText)
        write(undoText || "return {}\n")
    }

    Component.onDestruction: if (countdown > 0) revert()

    Process {
        id: listProc
        running: true
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.mons = JSON.parse(this.text).filter(m => !m.disabled) } catch (e) { page.mons = [] }
                if (!page.mons.some(m => m.name === page.sel) && page.mons.length)
                    page.sel = (page.mons.find(m => m.focused) || page.mons[0]).name
            }
        }
    }
    Timer { id: refreshTimer; interval: 1500; onTriggered: listProc.running = true }
    Timer {
        running: page.countdown > 0
        interval: 1000
        repeat: true
        onTriggered: {
            if (page.countdown <= 1) page.revert()
            else page.countdown--
        }
    }
    FileView {
        path: page.file
        printErrors: false
        onLoaded: { page.fileText = text(); page.rules = page.parse(page.fileText) }
    }

    // ---- keep or revert, while a change is pending
    SetCard {
        visible: page.countdown > 0
        title: "keep these settings?"
        RowLayout {
            width: parent.width
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "reverting in " + page.countdown + " s"
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.fg
            }
            SettingsHwButton { text: "revert"; onClicked: page.revert() }
            SettingsHwButton { text: "keep"; filled: true; onClicked: page.keep() }
        }
    }

    // ---- layout: every monitor drawn to scale; click one to edit it
    SetCard {
        title: "layout"
        Item {
            id: pic
            width: parent.width
            height: 130
            readonly property var boxes: page.mons.map(m => {
                const rot = (m.transform || 0) % 2 === 1
                const s = m.scale || 1
                return {name: m.name, x: m.x, y: m.y, w: (rot ? m.height : m.width) / s, h: (rot ? m.width : m.height) / s,
                    label: m.width + "x" + m.height + " · " + page.hz(m.refreshRate)}
            })
            readonly property real minX: Math.min.apply(null, boxes.map(b => b.x).concat([0]))
            readonly property real minY: Math.min.apply(null, boxes.map(b => b.y).concat([0]))
            readonly property real spanW: Math.max.apply(null, boxes.map(b => b.x + b.w).concat([1])) - minX
            readonly property real spanH: Math.max.apply(null, boxes.map(b => b.y + b.h).concat([1])) - minY
            readonly property real k: Math.min(width / spanW, height / spanH)
            readonly property real offX: (width - spanW * k) / 2

            Repeater {
                model: pic.boxes
                Rectangle {
                    id: mon
                    required property var modelData
                    readonly property bool on: modelData.name === (page.cur ? page.cur.name : "")
                    x: pic.offX + (modelData.x - pic.minX) * pic.k + 2
                    y: (modelData.y - pic.minY) * pic.k + 2
                    width: modelData.w * pic.k - 4
                    height: modelData.h * pic.k - 4
                    color: Ui.alpha(on ? Theme.accent : Theme.fg, on ? 0.18 : 0.05)
                    border.color: on ? Theme.accent : Theme.muted
                    Column {
                        anchors.centerIn: parent
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.name; font { family: Theme.fontFamily; pixelSize: 12; bold: true } color: Theme.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.label; font { family: Theme.fontFamily; pixelSize: 10 } color: Theme.dim }
                    }
                    MouseArea { anchors.fill: parent; onClicked: page.sel = mon.modelData.name }
                }
            }
            Text {
                visible: page.mons.length === 0
                anchors.centerIn: parent
                text: "no monitors reported by hyprctl"
                font { family: Theme.fontFamily; pixelSize: 12 }
                color: Theme.dim
            }
        }
    }

    // ---- mode of the selected monitor
    SetCard {
        visible: !!page.cur
        title: page.cur ? "mode · " + page.cur.name : "mode"
        SetRow {
            label: "resolution"
            SetSeg {
                options: page.resolutions.map(r => [r, r])
                value: page.curRes
                onPicked: v => page.change("mode", v + "@" + (page.modes.filter(m => m.split("@")[0] === v)
                    .map(m => m.split("@")[1]).sort((a, b) => parseFloat(b) - parseFloat(a))[0] || "60"))
            }
        }
        SetRow {
            label: "refresh rate"
            SetSeg {
                options: page.rates.map(r => [r, page.hz(r)])
                value: page.rule ? page.rule.mode.split("@")[1] : ""
                onPicked: v => page.change("mode", page.curRes + "@" + v)
            }
        }
        SetRow {
            label: "scale"
            SetSeg {
                options: [["1", "1"], ["1.25", "1.25"], ["1.5", "1.5"], ["2", "2"]]
                value: page.rule ? page.rule.scale : ""
                onPicked: v => page.change("scale", v)
            }
        }
        SetRow {
            label: "rotation"
            SetSeg {
                options: [[0, "normal"], [1, "90°"], [2, "180°"], [3, "270°"]]
                value: page.rule ? page.rule.transform : 0
                onPicked: v => page.change("transform", v)
            }
        }
        SetRow {
            label: "adaptive sync"
            SetSeg {
                options: [[0, "off"], [1, "on"], [2, "fullscreen only"]]
                value: page.rule ? page.rule.vrr : 0
                onPicked: v => page.change("vrr", v)
            }
        }
        SetRow {
            visible: page.mons.length > 1
            label: "place"
            SetSeg {
                options: [["auto", "auto"], ["auto-left", "left"], ["auto-right", "right"], ["auto-up", "above"], ["auto-down", "below"]]
                value: page.rule ? page.rule.position : "auto"
                onPicked: v => page.change("position", v)
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "saved to ~/.config/hypr/rice-monitors.lua · changes revert after 15 s unless kept"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    // ---- brightness: the laptop backlight, or external monitors over DDC/CI (ddcutil)
    SetCard {
        id: bri
        title: "brightness"
        property string how: ""       // "backlight", "ddc" or "none"; "" while looking
        property real value: 50       // percent
        property real max: 100        // DDC raw maximum

        Process {
            running: true
            command: ["sh", "-c",
                "if brightnessctl -m -c backlight 2>/dev/null | grep -q .; then " +
                "  echo \"backlight $(brightnessctl -m -c backlight | head -n1 | cut -d, -f4 | tr -d %)\"; " +
                "elif command -v ddcutil >/dev/null; then v=$(ddcutil getvcp 10 --brief 2>/dev/null | head -n1); " +
                "  case \"$v\" in VCP*) echo \"ddc $v\";; *) echo none;; esac; " +
                "else echo none; fi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = this.text.trim().split(/\s+/)
                    if (p[0] === "backlight") { bri.how = "backlight"; bri.value = parseFloat(p[1]) || 50 }
                    else if (p[0] === "ddc" && p.length >= 6) {
                        // "ddc VCP 10 C <current> <max>"
                        bri.max = parseFloat(p[5]) || 100
                        bri.value = Math.round((parseFloat(p[4]) || 0) * 100 / bri.max)
                        bri.how = "ddc"
                    } else bri.how = "none"
                }
            }
        }
        // DDC/CI is slow (about a second per monitor): send only once the slider rests.
        Timer {
            id: briTimer
            interval: 500
            onTriggered: {
                if (bri.how === "backlight")
                    Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.round(bri.value) + "%"])
                else if (bri.how === "ddc")
                    Quickshell.execDetached(["sh", "-c",
                        "for d in $(ddcutil detect --brief 2>/dev/null | sed -n 's/^Display \\([0-9][0-9]*\\).*/\\1/p'); do " +
                        "ddcutil --display \"$d\" setvcp 10 \"$1\"; done", "sh", String(Math.round(bri.value * bri.max / 100))])
            }
        }

        SetRow {
            visible: bri.how === "backlight" || bri.how === "ddc"
            label: "brightness"
            Item {
                width: parent.width
                height: 18
                Slider {
                    anchors { left: parent.left; right: briText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    from: 1
                    to: 100
                    step: 1
                    value: bri.value
                    onMoved: v => { bri.value = Math.round(v); briTimer.restart() }
                }
                Text {
                    id: briText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 48
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(bri.value) + "%"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.fg
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: bri.how === "" ? "looking for a backlight or DDC/CI monitor…"
                : bri.how === "backlight" ? "laptop backlight (brightnessctl)"
                : bri.how === "ddc" ? "over DDC/CI: sets every external monitor that supports it (ddcutil)"
                : "no backlight or DDC/CI monitor found · external monitors need ddcutil and the i2c-dev module"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
