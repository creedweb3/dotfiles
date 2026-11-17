import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"
import "../panel"

// Settings > Display > Night light: hyprsunset on or off, its warmth, and when it runs.
// Saved to ~/.config/hypr/rice-night.conf as hyprsunset profiles; hyprsunset -c reads it, and
// hyprland.lua starts it at login when the first comment line says enabled=1.
Column {
    id: page
    spacing: 12

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-night.conf"
    property bool on: false
    property int temp: 4500
    property string schedule: "always"   // "always" or "custom"
    property string from: "21:00"
    property string to: "07:00"

    // "7:5" or "07:05" -> "07:05"; anything else -> ""
    function hhmm(t) {
        const m = /^\s*(\d{1,2}):(\d{2})\s*$/.exec(t)
        if (!m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59) return ""
        return (m[1].length === 1 ? "0" : "") + m[1] + ":" + m[2]
    }
    function render() {
        let t = "# Written by the rice settings window (Display > Night light); hyprsunset -c reads it.\n"
            + "# rice: enabled=" + (on ? 1 : 0) + " temp=" + temp + " schedule=" + schedule + " from=" + from + " to=" + to + "\n"
        if (schedule === "custom")
            t += "profile {\n    time = " + to + "\n    identity = 1\n}\n\n"
                + "profile {\n    time = " + from + "\n    temperature = " + temp + "\n}\n"
        else
            t += "profile {\n    time = 00:00\n    temperature = " + temp + "\n}\n"
        return t
    }
    // Write the file, then (re)start hyprsunset with it, or stop it.
    function apply() {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' \"$1\" > \"$2\"; pkill -x hyprsunset; " +
            "if [ \"$3\" = 1 ]; then sleep 0.2; setsid -f hyprsunset -c \"$2\" >/dev/null 2>&1; fi",
            "sh", render(), file, on ? "1" : "0"])
    }

    Process {
        running: true
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => page.on = code === 0
    }
    FileView {
        path: page.file
        printErrors: false
        onLoaded: {
            const m = /^# rice: enabled=(\d) temp=(\d+) schedule=(\w+) from=([\d:]+) to=([\d:]+)/m.exec(text())
            if (!m) return
            page.temp = parseInt(m[2])
            page.schedule = m[3] === "custom" ? "custom" : "always"
            page.from = m[4]
            page.to = m[5]
        }
    }
    Timer { id: applyTimer; interval: 400; onTriggered: page.apply() }

    SetCard {
        title: "night light"
        SetRow {
            label: "night light"
            SetSeg {
                options: [[false, "off"], [true, "on"]]
                value: page.on
                onPicked: v => { page.on = v; page.apply() }
            }
        }
        SetRow {
            visible: page.on
            label: "warmth"
            Item {
                width: parent.width
                height: 18
                Slider {
                    anchors { left: parent.left; right: tempText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    // Left = cooler, right = warmer, so the slider reads as "more warmth".
                    from: 0
                    to: 40
                    step: 1
                    value: (6500 - page.temp) / 100
                    onMoved: v => { page.temp = 6500 - Math.round(v) * 100; applyTimer.restart() }
                }
                Text {
                    id: tempText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: page.temp + " K"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.fg
                }
            }
        }
        SetRow {
            label: "schedule"
            SetSeg {
                options: [["always", "always"], ["custom", "custom"]]
                value: page.schedule
                onPicked: v => { page.schedule = v; page.apply() }
            }
        }
        SetRow {
            visible: page.schedule === "custom"
            label: "from · to"
            Row {
                spacing: 8
                SettingsHwField {
                    text: page.from
                    onEdited: t => { const v = page.hhmm(t); if (v) { page.from = v; page.apply() } else text = page.from }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "→"; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.dim }
                SettingsHwField {
                    text: page.to
                    onEdited: t => { const v = page.hhmm(t); if (v) { page.to = v; page.apply() } else text = page.to }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "custom: warm from the first time, normal again at the second (24 h clock) · saved to ~/.config/hypr/rice-night.conf"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
