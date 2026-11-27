import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"
import "Ui.js" as Ui
import "Keymap.js" as Keymap

// Shortcuts sheet (SUPER+/): super drawn held on a keyboard, the keys it reaches lit, the full index below.
// Typing searches; up/down picks, enter runs the picked shortcut, esc clears the search, then closes.
Scope {
    id: root

    property string query: ""
    property int sel: 0
    property int rev: 0   // bumped when rice-keys.lua changes, so changed shortcuts show
    readonly property var hits: Keymap.matches(query, rev)
    readonly property var picked: query ? hits[sel] || null : null
    readonly property var lit: Keymap.lit(query, picked, rev)

    readonly property int unit: 44
    readonly property int gap: 5
    readonly property int kbWidth: 15 * unit + 14 * gap + 16 + 3 * unit + 2 * gap
    readonly property color fg30: Ui.mix(Theme.fg, Theme.bg, 0.30)
    readonly property color fg55: Ui.mix(Theme.fg, Theme.bg, 0.55)

    function show() {
        query = ""
        sel = 0
        card.topY = -1
        win.show()
        Qt.callLater(() => card.forceActiveFocus())
    }
    function hide() { win.open = false }
    function toggle() { win.open ? hide() : show() }
    // Close first, so the action reaches the window that was focused before the sheet.
    function run(row) {
        hide()
        Qt.callLater(() => Keymap.run(row, Hyprland, Quickshell))
    }

    function key(e) {
        const n = hits.length
        if (e.key === Qt.Key_Escape) {
            if (query) { query = ""; sel = 0 } else hide()
        } else if (e.text === "/" && !query) {
            hide()
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (picked) run(picked)
        } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            if (n) sel = (sel + (e.key === Qt.Key_Down ? 1 : n - 1)) % n
        } else if (e.key === Qt.Key_Backspace) {
            query = query.slice(0, -1)
            sel = 0
        } else if (e.text.length === 1 && e.text >= " ") {
            if (card.topY < 0) card.topY = card.y  // keep the card still while the index shrinks
            query += e.text.toLowerCase()
            sel = 0
        } else {
            return
        }
        e.accepted = true
    }

    // Shortcuts changed in Settings > Shortcuts (hyprland.lua binds the same file).
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/rice-keys.lua"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { Keymap.setOverrides(Keymap.readFile(text())); root.rev++ }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.toggle() }
    }

    // One key of the drawn keyboard.
    component Key: Item {
        property string label
        property real w: 1
        readonly property bool sup: label === "super"
        readonly property bool on: root.lit[label] !== undefined
        width: w * root.unit + (w - 1) * root.gap
        height: 44
        Rectangle {
            anchors.fill: parent
            color: parent.sup ? Theme.accent : parent.on ? Ui.alpha(Ui.mix(Theme.accent, Theme.bg, 0.16), 0.85) : Ui.alpha(Theme.bg, 0.7)
            border.color: parent.sup ? Theme.accent : parent.on ? Ui.alpha(Theme.accent, 0.7) : Ui.alpha(Theme.fg, 0.12)
        }
        Rectangle {  // the thicker bottom edge of a keycap
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 3
            color: parent.sup ? Theme.accent : parent.on ? Ui.alpha(Theme.accent, 0.7) : Ui.alpha(Theme.fg, 0.12)
        }
        Text {
            x: 7; y: 6
            text: parent.label.trim()
            font { family: Theme.fontFamily; pixelSize: 12; bold: parent.sup || parent.on }
            color: parent.sup ? Theme.bg : parent.on ? Theme.fg : root.fg30
        }
        Text {
            x: 7; y: 28
            width: parent.width - 10
            elide: Text.ElideNone
            clip: true
            text: parent.sup ? "held" : parent.on ? root.lit[parent.label] : ""
            font { family: Theme.fontFamily; pixelSize: 9 }
            color: parent.sup ? Theme.bg : Theme.accent
        }
    }

    // A keycap in the index. Dashed: pressed without super.
    component Cap: Item {
        id: cap
        property string label
        property bool ns: false
        property bool sup: false
        implicitWidth: Math.max(24, capText.implicitWidth + 12)
        implicitHeight: 22
        Rectangle {
            visible: !parent.ns
            anchors.fill: parent
            color: parent.sup ? Theme.accent : Ui.alpha(Theme.bg, 0.6)
            border.color: parent.sup ? Theme.accent : Ui.alpha(Theme.fg, 0.24)
        }
        Rectangle {
            visible: !parent.ns
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: parent.sup ? Theme.accent : Ui.alpha(Theme.fg, 0.24)
        }
        Shape {
            visible: parent.ns
            anchors.fill: parent
            ShapePath {
                strokeColor: Ui.alpha(Theme.fg, 0.24)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 2]
                fillColor: Ui.alpha(Theme.bg, 0.6)
                startX: 0.5; startY: 0.5
                PathLine { x: cap.width - 0.5; y: 0.5 }
                PathLine { x: cap.width - 0.5; y: cap.height - 0.5 }
                PathLine { x: 0.5; y: cap.height - 0.5 }
                PathLine { x: 0.5; y: 0.5 }
            }
        }
        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            font { family: Theme.fontFamily; pixelSize: 12; bold: parent.sup }
            color: parent.sup ? Theme.bg : parent.ns ? Ui.mix(Theme.fg, Theme.bg, 0.75) : Theme.fg
        }
    }

    // One group of the index: accent outline, tinted header strip, a row per shortcut.
    component Group: Rectangle {
        id: grp
        property string name
        readonly property var rows: Keymap.rowsOf(name, root.query, root.rev)
        visible: rows.length > 0
        Layout.fillWidth: true
        implicitHeight: groupCol.implicitHeight + 8
        color: "transparent"
        border.color: Ui.alpha(Theme.accent, 0.45)
        Column {
            id: groupCol
            x: 1; y: 1
            width: parent.width - 2
            Rectangle {
                width: parent.width
                height: 27
                color: Ui.alpha(Theme.accent, 0.16)
                Text {
                    x: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: grp.name.toUpperCase()
                    font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 3 }
                    color: Theme.accent
                }
            }
            Item { width: 1; height: 4 }
            Repeater {
                model: grp.rows
                Item {
                    id: rowItem
                    required property var modelData
                    readonly property bool picked: !!root.picked && root.picked[0] === modelData[0]
                    readonly property var keys: Keymap.parse(modelData[1])
                    width: groupCol.width
                    height: 27
                    Rectangle {
                        x: 5; width: parent.width - 10; height: parent.height
                        visible: rowItem.picked
                        color: Ui.alpha(Theme.accent, 0.12)
                        Rectangle { width: 2; height: parent.height; color: Theme.accent }
                    }
                    RowLayout {
                        x: 13; width: parent.width - 26; height: parent.height
                        spacing: 10
                        Text {
                            // long names with two key caps would run into the next column
                            Layout.maximumWidth: rowItem.width - 26 - capsRow.implicitWidth - 20
                            elide: Text.ElideRight
                            text: Ui.mark(rowItem.modelData[0], root.query, Theme.accent)
                            textFormat: Text.StyledText
                            font { family: Theme.fontFamily; pixelSize: 13 }
                            color: Ui.mix(Theme.fg, Theme.bg, 0.86)
                        }
                        Item {  // dotted leader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.topMargin: 8
                            clip: true
                            Repeater {
                                model: Math.ceil(parent.width / 4)
                                Rectangle { x: index * 4; width: 1; height: 1; color: Ui.alpha(Theme.fg, 0.18) }
                            }
                        }
                        Row {
                            id: capsRow
                            spacing: 4
                            Repeater {
                                model: rowItem.keys.k
                                Cap { required property var modelData; label: modelData; ns: !rowItem.keys.sup }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.run(rowItem.modelData) }
                }
            }
        }
    }

    OverlayWindow {
        id: win
        name: "cheatsheet"
        dim: 0.45
        onDismissed: root.hide()

        Rectangle {
            id: card
            property real topY: -1
            anchors.horizontalCenter: parent.horizontalCenter
            y: topY < 0 ? Math.round((parent.height - height) / 2) : topY
            width: root.kbWidth + 56
            height: body.implicitHeight + 38
            color: Theme.glass
            border.color: Theme.muted
            focus: true
            Keys.onPressed: e => root.key(e)

            MouseArea { anchors.fill: parent }  // clicks on the card stay off the scrim

            ColumnLayout {
                id: body
                x: 28; y: 22
                width: root.kbWidth
                spacing: 0

                RowLayout {  // symbol, label, search
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    spacing: 14
                    Symbol { size: 24 }
                    Text {
                        text: "HOLDING SUPER"
                        font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 4 }
                        color: Ui.mix(Theme.fg, Theme.bg, 0.75)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: Ui.alpha(Theme.bg, 0.55)
                        border.color: root.query ? Theme.accent : Ui.alpha(Theme.fg, 0.14)
                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.query ? root.query + "▌" : "type to search"
                            textFormat: Text.PlainText
                            font { family: Theme.fontFamily; pixelSize: 13 }
                            color: root.query ? Theme.accent : Ui.mix(Theme.fg, Theme.bg, 0.4)
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: root.query ? root.hits.length + " found" : "‹ esc"
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            color: root.fg55
                        }
                    }
                }

                Row {  // keyboard and arrow cluster
                    spacing: 16
                    Column {
                        spacing: root.gap
                        Repeater {
                            model: Keymap.ROWS
                            Row {
                                id: kbRow
                                required property var modelData
                                spacing: root.gap
                                Repeater {
                                    model: kbRow.modelData
                                    Key { required property var modelData; label: modelData[0]; w: modelData[1] }
                                }
                            }
                        }
                    }
                    Grid {
                        anchors.bottom: parent.bottom
                        columns: 3
                        spacing: root.gap
                        Item { width: root.unit; height: root.unit }
                        Key { label: "↑" }
                        Item { width: root.unit; height: root.unit }
                        Key { label: "←" }
                        Key { label: "↓" }
                        Key { label: "→" }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 16; Layout.preferredHeight: 1; color: Ui.alpha(Theme.fg, 0.10) }

                RowLayout {  // the index: three columns that end on one line
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 12
                    visible: root.hits.length > 0
                    Repeater {
                        model: [["apps", "windows"], ["workspaces", "media"], ["system"]]
                        ColumnLayout {
                            id: idxCol
                            required property var modelData
                            Layout.preferredWidth: (root.kbWidth - 24) / 3
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 12
                            Repeater {
                                model: idxCol.modelData
                                Group {
                                    required property var modelData
                                    required property int index
                                    name: modelData
                                    Layout.fillHeight: index === idxCol.modelData.length - 1
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: root.hits.length === 0
                    Layout.topMargin: 16
                    Layout.preferredHeight: 27
                    verticalAlignment: Text.AlignVCenter
                    text: "no shortcut matches"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: root.fg55
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; Layout.preferredHeight: 1; color: Ui.alpha(Theme.fg, 0.10) }

                RowLayout {  // footer
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Row {
                        spacing: 8
                        visible: !root.query
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "hold"; font { family: Theme.fontFamily; pixelSize: 12 } color: root.fg55 }
                        Cap { anchors.verticalCenter: parent.verticalCenter; label: "super"; sup: true }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "for every key ·"; font { family: Theme.fontFamily; pixelSize: 12 } color: root.fg55 }
                        Cap { anchors.verticalCenter: parent.verticalCenter; label: "dashed"; ns: true }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "no super"; font { family: Theme.fontFamily; pixelSize: 12 } color: root.fg55 }
                    }
                    Text {
                        visible: !!root.query
                        text: "↑ ↓ choose · ⏎ run · esc clears"
                        font { family: Theme.fontFamily; pixelSize: 12 }
                        color: root.fg55
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "edit in settings ›"
                        font { family: Theme.fontFamily; pixelSize: 12 }
                        color: editArea.containsMouse ? Theme.fg : root.fg55
                        MouseArea {
                            id: editArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.hide()
                                Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "settings", "openPage", "keys"])
                            }
                        }
                    }
                }
            }
        }
    }
}
