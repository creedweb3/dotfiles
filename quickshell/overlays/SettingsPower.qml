import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../common"

// Settings > System > Power: power profile (power-profiles-daemon), battery, the power button
// (Prefs.pbtn, read by hyprland.lua's XF86PowerOff bind when pressed), and the idle
// timeouts. The timeouts go to ~/.config/hypr/rice-idle.conf as variables that hypridle.conf
// sources over its defaults; hypridle restarts to pick them up.
Column {
    id: page
    spacing: 12

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-idle.conf"
    // Seconds; 0 = never. "lock" for screen off = 30 s after the lock.
    property int lock: 300
    property var off: "lock"
    property int sleep: 1800

    function render() {
        const dimOn = lock > 0, offT = off === "lock" ? lock + 30 : off, offOn = off === "lock" ? lock > 0 : off > 0
        // An empty value is false for hypridle.conf's "# hyprlang if" blocks.
        const v = (name, val) => "$" + name + " = " + val + "\n", b = x => x ? "1" : ""
        return "# Written by the rice settings window (System > Power); hypridle.conf sources it.\n"
            + "# rice: lock=" + lock + " off=" + off + " sleep=" + sleep + "\n"
            + v("dim_t", Math.max(lock - 30, 30)) + v("dim_on", b(dimOn))
            + v("lock_t", lock || 300) + v("lock_on", b(lock > 0))
            + v("off_t", offT || 330) + v("off_on", b(offOn))
            + v("sleep_t", sleep || 1800) + v("sleep_on", b(sleep > 0))
    }
    function apply() {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' \"$1\" > \"$2\"; pkill -x hypridle; sleep 0.2; setsid -f hypridle >/dev/null 2>&1",
            "sh", render(), file])
    }
    function mins(s) { return s >= 3600 ? s / 3600 + " h" : s / 60 + " min" }

    FileView {
        path: page.file
        printErrors: false
        onLoaded: {
            const m = /^# rice: lock=(\d+) off=(lock|\d+) sleep=(\d+)/m.exec(text())
            if (!m) return
            page.lock = parseInt(m[1])
            page.off = m[2] === "lock" ? "lock" : parseInt(m[2])
            page.sleep = parseInt(m[3])
        }
    }

    SetCard {
        title: "power profile"
        SetSeg {
            options: [[PowerProfile.PowerSaver, "power saver"], [PowerProfile.Balanced, "balanced"]]
                .concat(PowerProfiles.hasPerformanceProfile ? [[PowerProfile.Performance, "performance"]] : [])
            value: PowerProfiles.profile
            onPicked: v => PowerProfiles.profile = v
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "needs power-profiles-daemon (systemctl enable --now power-profiles-daemon)"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "when idle"
        SetRow {
            label: "lock after"
            SetSeg {
                options: [[300, "5 min"], [600, "10 min"], [1800, "30 min"], [0, "never"]]
                value: page.lock
                onPicked: v => { page.lock = v; page.apply() }
            }
        }
        SetRow {
            label: "screen off after"
            SetSeg {
                options: [["lock", "with the lock"], [900, "15 min"], [1800, "30 min"], [0, "never"]]
                value: page.off
                onPicked: v => { page.off = v; page.apply() }
            }
        }
        SetRow {
            label: "sleep after"
            SetSeg {
                options: [[900, "15 min"], [1800, "30 min"], [3600, "1 h"], [0, "never"]]
                value: page.sleep
                onPicked: v => { page.sleep = v; page.apply() }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "the screen dims 30 s before the lock · saved to ~/.config/hypr/rice-idle.conf"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "buttons"
        SetRow {
            label: "power button"
            pref: "pbtn"
            SetSeg {
                options: [["menu", "power menu"], ["off", "shut down"], ["sleep", "sleep"], ["nothing", "nothing"]]
                value: Prefs.pbtn
                onPicked: v => Prefs.set("pbtn", v)
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "power menu opens the launcher's power list · needs logind to leave the key to Hyprland (HandlePowerKey=ignore, see the README)"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        id: bat
        readonly property var dev: UPower.displayDevice
        readonly property bool has: !!dev && dev.isLaptopBattery
        readonly property real pct: has ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
        title: "battery"
        Text {
            visible: !bat.has
            text: "no battery (desktop)"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
        Repeater {
            model: bat.has ? [
                ["charge", Math.round(bat.pct) + "%"],
                ["state", UPowerDeviceState.toString(bat.dev.state).toLowerCase()],
                bat.dev.state === UPowerDeviceState.Discharging && bat.dev.timeToEmpty > 0
                    ? ["time left", page.mins(Math.round(bat.dev.timeToEmpty / 60) * 60)]
                    : bat.dev.state === UPowerDeviceState.Charging && bat.dev.timeToFull > 0
                    ? ["full in", page.mins(Math.round(bat.dev.timeToFull / 60) * 60)] : null
            ].filter(x => x) : []
            RowLayout {
                required property var modelData
                width: parent ? parent.width : 0
                Text { Layout.preferredWidth: 132; text: modelData[0]; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.dim }
                Text { Layout.fillWidth: true; text: modelData[1]; font { family: Theme.fontFamily; pixelSize: 13; bold: true } color: Theme.fg }
            }
        }
    }
}
