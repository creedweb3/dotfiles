import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "Ui.js" as Ui

// Settings > Theme: anime preset, wallpaper, and the colours picked from it.
Column {
    id: page
    spacing: 12

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property var presets: []
    property string preset: ""
    property var walls: []

    // read again on every theme change, so a preset that failed to switch shows the real one
    Connections {
        target: Theme
        function onRevChanged() { presetList.running = true }
    }
    Process {
        id: presetList
        running: true
        command: Ui.presetListCommand
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x)
                page.presets = lines.filter(x => x[0] !== "=")
                page.preset = (lines.find(x => x[0] === "=") || "=").slice(1)
            }
        }
    }
    Process {
        running: true
        command: ["find", page.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector { onStreamFinished: page.walls = this.text.split("\n").filter(x => x).sort() }
    }

    SetCard {
        title: "preset"
        SetSeg {
            options: page.presets.map(p => [p, p])
            value: page.preset
            onPicked: v => {
                page.preset = v
                Quickshell.execDetached(Ui.presetCommand(v))
            }
        }
        Text {
            visible: page.presets.length === 0
            text: "no presets found next to ~/.config/wallust"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "wallpaper"
        action: "picker"
        onActionClicked: Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "wallpaper", "toggle"])
        Grid {
            id: grid
            width: parent.width
            columns: 4
            spacing: 8
            readonly property real cell: (width - 3 * spacing) / 4
            Repeater {
                model: page.walls
                Rectangle {
                    required property var modelData
                    readonly property bool on: modelData === Theme.wallpaperPath || modelData.slice(modelData.lastIndexOf("/") + 1) === Theme.wallpaperName
                    width: grid.cell
                    height: width * 9 / 16
                    color: "transparent"
                    border { color: on ? Theme.accent : area.containsMouse ? Theme.dim : Theme.muted; width: on ? 2 : 1 }
                    Image {
                        anchors { fill: parent; margins: parent.on ? 2 : 1 }
                        source: "file://" + parent.modelData
                        sourceSize.width: 320
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["sh", "-c", "w=\"$HOME/.local/bin/wall\"; [ -x \"$w\" ] || w=wall; exec \"$w\" \"$1\"", "sh", parent.modelData])
                    }
                }
            }
        }
        Text {
            visible: page.walls.length === 0
            text: "no wallpapers in ~/Pictures/wallpapers"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "colours · " + Theme.kind
        Row {
            spacing: 8
            Repeater {
                model: [["bg", Theme.bg], ["panel", Theme.panel], ["muted", Theme.muted], ["dim", Theme.dim],
                    ["fg", Theme.fg], ["accent", Theme.accent], ["accent2", Theme.accent2]]
                Column {
                    required property var modelData
                    spacing: 4
                    Rectangle { width: 56; height: 30; color: parent.modelData[1]; border.color: Theme.muted }
                    Text { text: parent.modelData[0]; font { family: Theme.fontFamily; pixelSize: 11 } color: Theme.dim }
                }
            }
        }
        Text {
            text: "picked from the wallpaper; a new wallpaper re-colours everything"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
