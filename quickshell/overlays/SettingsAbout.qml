import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"

// Settings > About: this PC at a glance, and pending updates (checkupdates for the repos,
// yay for the AUR). "update now" runs yay -Syu in kitty, so the password prompt is visible.
Column {
    id: page
    spacing: 12

    property var info: []        // [label, value]
    property int updState: 0     // 0 not checked, 1 checking, 2 done
    property var updates: []     // [package, "old -> new"]

    Process {
        running: true
        command: ["sh", "-c",
            ". /etc/os-release 2>/dev/null; echo \"os=${PRETTY_NAME:-Linux}\"; echo \"kernel=$(uname -r)\"; " +
            "v=$(hyprctl version 2>/dev/null | head -n1); case $v in Hyprland*) v=$(echo \"$v\" | cut -d' ' -f1-2) ;; *) v='Hyprland not running' ;; esac; echo \"compositor=$v\"; echo \"shell=Quickshell\"; " +
            "echo \"user=$USER\"; " +
            "echo \"preset=$(basename \"$(dirname \"$(readlink \"$HOME/.config/wallust/templates/symbol.svg\")\")\")\"; " +
            "s=$(cut -d. -f1 /proc/uptime); echo \"up=$((s / 3600)) h $((s % 3600 / 60)) min\"; " +
            "echo \"dotfiles=$(readlink -f \"$HOME/.config/wallust/..\" | sed \"s|^$HOME|~|\")\""]
        stdout: StdioCollector {
            onStreamFinished: page.info = this.text.split("\n").filter(x => x.indexOf("=") > 0)
                .map(x => [x.slice(0, x.indexOf("=")), x.slice(x.indexOf("=") + 1)])
        }
    }
    Process {
        id: updProc
        // "pkg old -> new" from both; either tool may be missing or find nothing (non-zero exit)
        command: ["sh", "-c", "checkupdates 2>/dev/null; yay -Qua 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.updates = this.text.split("\n").filter(x => x.trim()).map(x => {
                    const i = x.indexOf(" ")
                    return [x.slice(0, i), x.slice(i + 1)]
                })
                page.updState = 2
            }
        }
    }

    component KeyRow: RowLayout {
        property string key
        property string value
        width: parent ? parent.width : 0
        Text { Layout.preferredWidth: 132; text: parent.key; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.dim }
        Text { Layout.fillWidth: true; text: parent.value; elide: Text.ElideRight; font { family: Theme.fontFamily; pixelSize: 13; bold: true } color: Theme.fg }
    }

    SetCard {
        title: "this pc"
        Repeater {
            model: page.info.map(x => x[0] === "preset" ? ["theme", x[1] + " · " + Theme.kind] : x)
            KeyRow { required property var modelData; key: modelData[0]; value: modelData[1] }
        }
    }

    SetCard {
        title: "updates"
        action: page.updState === 1 ? "checking…" : "check now"
        onActionClicked: if (page.updState !== 1) { page.updState = 1; updProc.running = true }
        Text {
            visible: page.updState !== 2
            text: page.updState === 1 ? "asking the mirrors…" : "not checked yet"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
        Text {
            visible: page.updState === 2 && page.updates.length === 0
            text: "everything is up to date"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
        Repeater {
            model: page.updState === 2 ? page.updates.slice(0, 40) : []
            KeyRow { required property var modelData; key: modelData[0]; value: modelData[1] }
        }
        RowLayout {
            visible: page.updState === 2 && page.updates.length > 0
            width: parent.width
            Text {
                Layout.fillWidth: true
                text: page.updates.length + " updates"
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.fg
            }
            Rectangle {
                width: btnText.implicitWidth + 20
                height: 26
                color: btnArea.containsMouse ? Theme.accent : "transparent"
                border.color: Theme.accent
                Text { id: btnText; anchors.centerIn: parent; text: "update now"; font { family: Theme.fontFamily; pixelSize: 13 } color: btnArea.containsMouse ? Theme.bg : Theme.accent }
                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["kitty", "-e", "bash", "-c", "yay -Syu; echo; read -rp 'done, press enter to close ' _"])
                }
            }
        }
    }
}
