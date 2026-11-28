import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../overlays/Ui.js" as Ui

// Quick panel, theme tab, as in the demo: the current wallpaper with the preset name, its place
// in ~/Pictures/wallpapers, the palette and previous / next arrows; the presets as tiles; and the
// glass & depth sliders with "all settings" and "reset" links. Uses the same commands as
// Settings > Theme, and the window sliders write rice-settings.lua as Settings > Windows does.
// Border tint and behind blur only show once their settings exist (border_tint in
// rice-settings.lua; the Prefs setting sblur). Hyprland cannot tint windows, so no window tint.
Column {
    id: root

    spacing: 10

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property var presets: []      // names
    property var counts: ({})     // preset -> wallpapers in its folder
    property var groupFiles: ({}) // preset -> file names of its wallpapers
    property string presetsDir: ""
    property string preset: ""
    property var allWalls: []     // everything in ~/Pictures/wallpapers
    // the arrows and the counter stay inside the current group (all of them if it has none listed)
    readonly property var walls: {
        const names = groupFiles[preset] || [];
        const own = allWalls.filter(w => names.includes(w.slice(w.lastIndexOf("/") + 1)));
        return own.length ? own : allWalls;
    }
    readonly property int index: walls.indexOf(Theme.wallpaperPath)

    function setWall(path) {
        Quickshell.execDetached(["sh", "-c", "w=\"$HOME/.local/bin/wall\"; [ -x \"$w\" ] || w=wall; exec \"$w\" \"$1\"", "sh", path]);
    }
    function step(d) {
        const n = walls.length;
        if (n > 1)
            setWall(walls[((index < 0 ? 0 : index + d) % n + n) % n]);
    }

    Process {
        running: true
        command: Ui.presetListCommand
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x);
                root.presets = lines.filter(x => x[0] !== "=");
                root.preset = (lines.find(x => x[0] === "=") || "=").slice(1);
            }
        }
    }
    // where the presets live, and how many wallpapers each one has
    Process {
        running: true
        // the presets folder, then one "<preset> <file name>" line per wallpaper
        command: ["sh", "-c", "d=$(readlink -f \"$HOME/.config/wallust\")/../presets; readlink -f \"$d\"; for p in \"$d\"/*/; do n=$(basename \"$p\"); find \"$p/wallpapers\" -type f 2>/dev/null | while read -r f; do echo \"$n $(basename \"$f\")\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x), c = {}, g = {};
                root.presetsDir = lines.shift() || "";
                for (const l of lines) {
                    const m = /^(\S+) (.+)$/.exec(l);
                    if (!m)
                        continue;
                    (g[m[1]] = g[m[1]] || []).push(m[2]);
                    c[m[1]] = g[m[1]].length;
                }
                root.groupFiles = g;
                root.counts = c;
            }
        }
    }
    Process {
        running: true
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.allWalls = this.text.split("\n").filter(x => x).sort()
        }
    }

    Card {
        width: parent.width

        // hero: the wallpaper, darkened at the bottom under the preset name
        Rectangle {
            width: parent.width
            height: 150
            color: Theme.panel
            border.width: 1
            border.color: Theme.muted
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Theme.wallpaperPath ? "file://" + Theme.wallpaperPath : ""
                sourceSize.width: 1000
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
                spacing: 3

                Label {
                    text: root.preset || "no preset"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                }
                Label {
                    text: root.walls.length ? "wallpaper " + (root.index + 1 || "?") + " / " + root.walls.length : "no wallpapers yet"
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
                Row {
                    topPadding: 3
                    spacing: 3
                    Repeater {
                        model: [Theme.bg, Theme.muted, Theme.dim, Theme.accent, Theme.accent2, Theme.fg]
                        Rectangle {
                            required property var modelData
                            width: 14
                            height: 8
                            color: modelData
                        }
                    }
                }
            }

            Row {
                visible: root.walls.length > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                spacing: 4

                Repeater {
                    model: [[-1, "‹", "previous wallpaper"], [1, "›", "next wallpaper"]]
                    Rectangle {
                        required property var modelData
                        width: 28
                        height: 28
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: arrow.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.35)
                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData[1]
                            color: arrow.containsMouse ? Theme.accent : "white"
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: arrow
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.step(parent.modelData[0])
                        }
                    }
                }
            }
        }

        // presets: the symbol, the name and how many wallpapers come with it
        Grid {
            id: tiles
            width: parent.width
            columns: 3
            spacing: 8

            Repeater {
                model: root.presets
                Rectangle {
                    id: tile
                    required property string modelData
                    readonly property bool on: modelData === root.preset
                    width: (tiles.width - tiles.spacing * 2) / 3
                    height: 58
                    color: on ? Theme.alpha(Theme.accent, 0.16) : "transparent"
                    border.width: 1
                    border.color: on || tileMouse.containsMouse ? Theme.accent : Theme.muted

                    Row {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Image {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.presetsDir ? "file://" + root.presetsDir + "/" + tile.modelData + "/symbol.svg" : ""
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label {
                                text: tile.modelData
                                font.weight: Font.DemiBold
                            }
                            Label {
                                readonly property int n: root.counts[tile.modelData] || 0
                                text: n + " wallpaper" + (n === 1 ? "" : "s")
                                color: Theme.dim
                                font.pixelSize: Theme.smallSize
                            }
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.preset = tile.modelData;
                            Quickshell.execDetached(Ui.presetCommand(tile.modelData));
                        }
                    }
                }
            }
        }
    }

    WindowGlass {
        id: glass
    }

    // the demo's eight sliders: [label, min, max, unit, read(), write(v), shown()]. Functions, so
    // this list never changes and the rows are not rebuilt while a slider is dragged.
    readonly property bool hasSblur: Prefs.spec.sblur !== undefined
    readonly property var glassRows: [
        ["window opacity", 40, 100, "%", () => glass.values.active_opacity * 100, v => {
            // keep the gap between focused and other windows, as one demo slider moves both
            const gap = glass.values.active_opacity - glass.values.inactive_opacity;
            glass.setMany({active_opacity: v / 100, inactive_opacity: Math.max(0.4, v / 100 - gap)});
        }, () => true],
        ["blur", 0, 30, "px", () => glass.values.blur_size, v => glass.set("blur_size", v), () => true],
        ["border tint", 0, 100, "%", () => (glass.values.border_tint ?? 0.4) * 100, v => glass.set("border_tint", v / 100), () => glass.has("border_tint")],
        ["border width", 1, 3, "px", () => glass.values.border_size, v => glass.set("border_size", v), () => true],
        ["graph strength", 45, 100, "%", () => Prefs.gs, v => Prefs.set("gs", v), () => true],
        ["behind blur", 0, 12, "px", () => root.hasSblur ? Prefs.sblur : 0, v => Prefs.set("sblur", v), () => root.hasSblur],
        ["behind dim", 0, 70, "%", () => Prefs.sdim, v => Prefs.set("sdim", v), () => true]]
    readonly property bool changed: !glass.isDefault() || (glass.has("border_tint") && glass.values.border_tint !== 0.4)
        || !Prefs.isDefault("gs") || !Prefs.isDefault("sdim") || (hasSblur && !Prefs.isDefault("sblur"))

    function resetGlass() {
        const kv = Object.assign({}, glass.defaults);
        if (glass.has("border_tint"))
            kv.border_tint = 0.4;
        glass.setMany(kv);
        for (const k of ["gs", "sdim"].concat(hasSblur ? ["sblur"] : []))
            Prefs.reset(k);
    }

    component Link: Label {
        id: lk
        signal activated
        color: lkMouse.containsMouse ? Theme.accent : Theme.dim
        font.pixelSize: Theme.smallSize
        MouseArea {
            id: lkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lk.activated()
        }
    }

    Card {
        width: parent.width

        // title row with its links, as the demo's card head
        Item {
            width: parent.width
            height: 16
            Label {
                text: "GLASS & DEPTH"
                color: Theme.dim
                font.pixelSize: Theme.smallSize
                font.letterSpacing: 2
            }
            Row {
                anchors.right: parent.right
                spacing: 12
                Link {
                    visible: root.changed
                    text: "reset"
                    onActivated: root.resetGlass()
                }
                Link {
                    text: "all settings ›"
                    onActivated: {
                        Popup.close();
                        Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "settings", "openPage", "windows"]);
                    }
                }
            }
        }

        Repeater {
            model: root.glassRows
            RangeRow {
                required property var modelData
                readonly property real shown: modelData[4]()
                visible: modelData[6]()
                width: parent.width
                label: modelData[0]
                // RangeRow's slider runs 0-100: map this row's range onto it
                value: (shown - modelData[1]) / (modelData[2] - modelData[1]) * 100
                valueText: Math.round(shown) + modelData[3]
                onMoved: v => modelData[5](Math.round(modelData[1] + v / 100 * (modelData[2] - modelData[1])))
            }
        }
    }
}
