import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../panel"
import "Ui.js" as Ui

// Settings > Windows: the glass look of every window. Saved to ~/.config/hypr/rice-settings.lua,
// which hyprland.lua applies after its own values; Hyprland reloads to show the change.
// The quick panel's Theme tab (panel/WindowGlass.qml) writes the same file, so every `key = number`
// line is kept on save, known here or not, and the file is reread when it changes.
//   border_tint  0-1, accent mixed into the unfocused windows' border (0 = the palette's muted grey)
// The demo's window tint (accent mixed into the glass) has no slider here: Hyprland has no colour
// tint for windows. A window_tint line written by someone else is kept as it is.
Column {
    id: page
    spacing: 12

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-settings.lua"
    // Hyprland's values in hyprland.lua, used until the file exists and by "reset".
    readonly property var defaults: ({active_opacity: 0.94, inactive_opacity: 0.88, blur_size: 6, border_size: 2, border_tint: 0.4})
    property var values: Object.assign({}, defaults)
    // [key, label, from, to, step, unit, factor shown]
    readonly property var rows: [
        ["active_opacity", "focused window", 40, 100, 1, "%", 100],
        ["inactive_opacity", "other windows", 40, 100, 1, "%", 100],
        ["blur_size", "blur", 0, 30, 1, "px", 1],
        ["border_tint", "border tint", 0, 100, 1, "%", 100],
        ["border_size", "border width", 1, 3, 1, "px", 1]]

    function set(key, v) {
        const next = Object.assign({}, values)
        next[key] = v
        values = next
        saveTimer.restart()
    }
    function save() {
        const r = v => Math.round(v * 100) / 100
        let body = ""
        for (const k in values) if (/^\w+$/.test(k) && isFinite(values[k])) body += "    " + k + " = " + r(values[k]) + ",\n"
        settingsFile.setText("-- Written by the rice settings window (Quickshell). hyprland.lua applies this after its own values.\n"
            + "return {\n" + body + "}\n")
        Quickshell.execDetached(["hyprctl", "reload"])
    }

    FileView {
        id: settingsFile
        path: page.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const next = Object.assign({}, page.values)
            const re = /^\s*(\w+)\s*=\s*(-?[\d.]+)/gm, t = text()
            let m
            while ((m = re.exec(t)) !== null) next[m[1]] = parseFloat(m[2])
            page.values = next
        }
    }
    // Write once the slider rests, so dragging does not reload Hyprland on every step.
    Timer { id: saveTimer; interval: 400; onTriggered: page.save() }

    SetCard {
        title: "glass"
        action: "reset"
        onActionClicked: { page.values = Object.assign({}, page.values, page.defaults); page.save() }
        Repeater {
            model: page.rows
            SetRow {
                id: row
                required property var modelData
                readonly property real factor: modelData[6]
                readonly property real shown: page.values[modelData[0]] * factor
                label: modelData[1]
                Item {
                    width: parent.width
                    height: 18
                    Slider {
                        anchors { left: parent.left; right: valueText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        from: row.modelData[2]
                        to: row.modelData[3]
                        step: row.modelData[4]
                        value: row.shown
                        onMoved: v => page.set(row.modelData[0], Math.round(v) / row.factor)
                    }
                    Text {
                        id: valueText
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 48
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(row.shown) + row.modelData[5]
                        font { family: Theme.fontFamily; pixelSize: 13 }
                        color: Theme.fg
                    }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "saved to ~/.config/hypr/rice-settings.lua"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
}
