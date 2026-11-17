import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"
import "Ui.js" as Ui
import "Keymap.js" as Keymap

// Settings > Shortcuts: every shortcut, searchable. Click one, then press the new keys (esc cancels);
// with no modifier held SUPER is added. Changes go to ~/.config/hypr/rice-keys.lua, which hyprland.lua
// reads, and apply at once with `hyprctl reload`.
Column {
    id: page
    spacing: 12
    signal close()
    property string query: ""
    property string rec: ""   // id of the shortcut waiting for new keys
    property string msg: ""   // what happened to the last try
    property int rev: 0       // bumped whenever the keys change, so the lists redraw
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-keys.lua"

    function rowById(id) {
        for (const g of Keymap.groups) for (const r of g[1]) if (r[3] === id) return r
        return null
    }
    // Hyprland would run the old shortcut before the window sees the keys, so switch it to an
    // empty submap while recording.
    function start(row) {
        if (!row[3]) { msg = row[0] + " uses several keys, the mouse or a media key: it can't be changed here"; return }
        stop()
        rec = row[3]
        msg = ""
        Hyprland.dispatch('hl.dsp.submap("rice-record")')
        recorder.forceActiveFocus()
        recTimeout.restart()
    }
    function stop() {
        if (!rec) return
        rec = ""
        recTimeout.stop()
        Hyprland.dispatch('hl.dsp.submap("reset")')
    }
    function save() {
        rev++
        // Detached, so the write lands even if the settings window closes right away.
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && hyprctl reload >/dev/null",
                                 "sh", Keymap.fileText(Keymap.overrides()), file])
    }
    function pressed(e) {
        if (!rec) { e.accepted = false; return }   // not recording: esc still closes the window
        e.accepted = true
        if (e.key === Qt.Key_Escape) { stop(); msg = ""; return }
        const r = Keymap.comboOf(e.key, e.modifiers)
        if (!r) return   // a modifier on its own: wait for the key
        const row = rowById(rec)
        stop()
        if (!row) return
        if (r.err) { msg = r.err; return }
        const other = Keymap.clash(row, r.combo)
        if (other) { msg = r.combo + " is already “" + other + "”: pick another"; return }
        if (r.combo === row[1]) return
        msg = row[0] + ": " + row[1] + " → " + r.combo
        row[1] = r.combo
        save()
    }
    function resetAll() {
        stop()
        Keymap.setOverrides({})
        msg = "every shortcut is back to its default"
        save()
    }

    Component.onDestruction: stop()

    FileView {
        path: page.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { Keymap.setOverrides(Keymap.readFile(text())); page.rev++ }
    }
    // Never leave Hyprland in the empty submap for long.
    Timer { id: recTimeout; interval: 15000; onTriggered: { page.stop(); page.msg = "no keys pressed: recording stopped" } }

    // Takes the keys while recording. Losing focus (window closed, search clicked) cancels.
    Item {
        id: recorder
        width: 0; height: 0
        Keys.onPressed: e => page.pressed(e)
        onActiveFocusChanged: if (!activeFocus) page.stop()
    }

    Rectangle {
        width: parent.width
        height: 32
        color: Ui.alpha(Theme.bg, 0.55)
        border.color: search.activeFocus ? Theme.accent : Theme.muted
        TextInput {
            id: search
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.fg
            onTextChanged: page.query = text.toLowerCase().trim()
            Keys.onEscapePressed: text ? text = "" : page.close()
            Text { visible: !search.text; anchors.verticalCenter: parent.verticalCenter; text: "search shortcuts"; font: search.font; color: Theme.dim }
        }
    }

    Repeater {
        model: Keymap.groups
        SetCard {
            id: grp
            required property var modelData
            readonly property var rows: Keymap.rowsOf(modelData[0], page.query, page.rev)
            visible: rows.length > 0
            title: modelData[0]
            Repeater {
                model: grp.rows
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool recording: page.rec !== "" && page.rec === modelData[3]
                    width: parent.width
                    height: 26
                    color: recording ? Ui.alpha(Theme.accent, 0.16) : hover.containsMouse && modelData[3] ? Ui.alpha(Theme.accent, 0.08) : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                        Text {
                            Layout.fillWidth: true
                            text: Ui.mark(row.modelData[0], page.query, Theme.accent)
                            textFormat: Text.StyledText
                            font { family: Theme.fontFamily; pixelSize: 13 }
                            color: Theme.fg
                        }
                        Text {
                            text: row.recording ? "press new keys… esc cancels" : row.modelData[1].replace(/\+/g, " + ")
                            font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                            color: row.modelData[3] ? Theme.accent : Theme.dim
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.modelData[3] ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: row.recording ? page.stop() : page.start(row.modelData)
                    }
                }
            }
        }
    }
    Text {
        visible: Keymap.matches(page.query, page.rev).length === 0
        text: "no shortcut matches"
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: Theme.dim
    }
    Text {
        visible: page.msg !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: page.msg
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: Theme.accent
    }
    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "click a shortcut, then press the new keys. No modifier pressed: SUPER is added."
        font { family: Theme.fontFamily; pixelSize: 11 }
        color: Theme.dim
    }
    SettingsHwButton {
        visible: page.rev >= 0 && Object.keys(Keymap.overrides()).length > 0
        text: "reset shortcuts"
        onClicked: page.resetAll()
    }
}
