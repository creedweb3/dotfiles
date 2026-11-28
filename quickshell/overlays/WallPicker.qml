import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"
import "Ui.js" as Ui

// Wallpaper picker (SUPER+W): thumbnails from ~/Pictures/wallpapers. Moving previews one on the
// desktop (awww only, no re-colour); enter applies it with `wall` (wallpaper + colours), esc or a
// click outside puts the old one back. Settings > Panels > wallpaper picker (Prefs.wstyle):
//   carousel  a strip along the bottom, the selected one centred and larger (default)
//   side      a column along the right edge, search on top
//   grid      a centred gallery, four across, search on top
Scope {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property var walls: []            // {path, name}
    property int sel: 0
    property string filter: ""
    property string original: ""      // wallpaper before the picker opened
    property string previewed: ""
    property bool applied: false
    readonly property var shown: walls.filter(w => !filter || w.name.toLowerCase().indexOf(filter) >= 0)
    readonly property string look: Prefs.wstyle
    readonly property int cols: 4     // grid look

    function show() {
        applied = false
        original = Theme.wallpaperPath || ""
        previewed = original
        search.text = ""
        listProc.running = true
        win.show()
        Qt.callLater(() => search.forceActiveFocus())
    }
    function hide() {
        if (!win.open) return
        win.open = false
        previewTimer.stop()
        if (!applied && original && previewed !== original) awww(original)
    }
    function toggle() { win.open ? hide() : show() }

    function awww(path) {
        previewed = path
        Quickshell.execDetached(["awww", "img", path, "--transition-type", "fade", "--transition-duration", "0.3"])
    }
    function move(step) {
        if (!shown.length) return
        sel = Math.max(0, Math.min(shown.length - 1, sel + step))
        previewTimer.restart()
    }
    function apply() {
        const w = shown[sel]
        if (!w) return
        applied = true
        hide()
        // ~/.local/bin is not always on the PATH Quickshell starts with
        Quickshell.execDetached(["sh", "-c", "w=\"$HOME/.local/bin/wall\"; [ -x \"$w\" ] || w=wall; exec \"$w\" \"$1\"", "sh", w.path])
    }
    // arrow keys: along the strip or column; the grid also moves by rows
    function key(e) {
        const across = look === "carousel" || look === "grid", down = look === "side" ? 1 : look === "grid" ? cols : 0
        if (e.key === Qt.Key_Escape) hide()
        else if (e.key === Qt.Key_Left && across) move(-1)
        else if (e.key === Qt.Key_Right && across) move(1)
        else if (e.key === Qt.Key_Up && down) move(-down)
        else if (e.key === Qt.Key_Down && down) move(down)
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) apply()
        else return
        e.accepted = true
    }

    component Box: Rectangle {
        Layout.preferredHeight: 34
        color: Theme.glass
        border.color: Theme.muted
        layer.enabled: Prefs.shadow
        layer.effect: PanelShadow {}
    }

    // One thumbnail with its name. `wide`: the carousel's larger selected card.
    component WallCard: Rectangle {
        id: card
        required property var modelData
        required property int index
        readonly property bool picked: index === root.sel
        color: Theme.glass
        border.color: picked ? Theme.accent : cardArea.containsMouse ? Theme.dim : Theme.muted
        implicitHeight: cardCol.implicitHeight + 14
        layer.enabled: Prefs.shadow
        layer.effect: PanelShadow {}

        Column {
            id: cardCol
            x: 8; y: 8
            width: parent.width - 16
            spacing: 6
            Rectangle {
                width: parent.width
                height: width * 9 / 16
                color: "transparent"
                border.color: card.picked ? Theme.accent : Theme.muted
                Image {
                    anchors { fill: parent; margins: 1 }
                    source: "file://" + card.modelData.path
                    sourceSize.width: 500
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: card.modelData.name
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: card.picked ? Theme.fg : Theme.dim
            }
        }
        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { root.sel = card.index; root.apply() }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle() }
    }

    Process {
        id: listProc
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.walls = this.text.split("\n").filter(x => x).sort().map(p => ({
                    path: p, name: p.slice(root.dir.length + 1).replace(/\.[^.\/]+$/, "")}))
                root.sel = Math.max(0, root.shown.findIndex(w => w.path === root.original || w.path.slice(w.path.lastIndexOf("/") + 1) === Theme.wallpaperName))
            }
        }
    }
    // Preview after the selection rests a moment, so fast scrolling does not queue up awww calls.
    Timer {
        id: previewTimer
        interval: 250
        onTriggered: {
            const w = root.shown[root.sel]
            if (w && w.path !== root.previewed) root.awww(w.path)
        }
    }

    OverlayWindow {
        id: win
        name: "wallpaper"
        dim: Prefs.scrimAlpha
        onDismissed: root.hide()

        // The pane: where the picker sits for each look. The search row goes under the
        // thumbnails (carousel) or above them (side, grid).
        Item {
            id: pane
            readonly property bool searchTop: root.look !== "carousel"
            x: root.look === "side" ? parent.width - width - 14 : root.look === "grid" ? (parent.width - width) / 2 : 0
            y: root.look === "side" ? 48 : root.look === "grid" ? (parent.height - height) / 2 : parent.height - height - 14
            width: root.look === "side" ? 300 : root.look === "grid" ? Math.min(1100, parent.width * 0.84) : parent.width
            height: root.look === "side" ? parent.height - 48 - 14
                : root.look === "grid" ? searchRow.height + 8 + Math.min(gridH, parent.height * 0.66)
                : 182 + 8 + searchRow.height
            readonly property real gridH: Math.ceil(root.shown.length / root.cols) * (((width - 12 * (root.cols - 1)) / root.cols) * 9 / 16 + 50 + 12)

            MouseArea { anchors.fill: parent; enabled: pane.searchTop }  // clicks between cards stay inside

            Item {
                id: view
                anchors {
                    left: parent.left; right: parent.right
                    top: pane.searchTop ? searchRow.bottom : parent.top
                    topMargin: pane.searchTop ? 8 : 0
                    bottom: pane.searchTop ? parent.bottom : searchRow.top
                    bottomMargin: pane.searchTop ? 0 : 8
                }

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.look === "side" ? sideView : root.look === "grid" ? gridView : stripView
                }

                MouseArea {  // wheel moves the selection
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: w => root.move(((w.angleDelta.y || w.angleDelta.x) < 0 ? 1 : -1) * (root.look === "grid" ? root.cols : 1))
                }

                Text {
                    visible: root.shown.length === 0
                    anchors.centerIn: parent
                    text: root.walls.length ? "no wallpaper matches" : "no wallpapers in ~/Pictures/wallpapers"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.dim
                }
            }

            RowLayout {  // search row: glass boxes, like the bar
                id: searchRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: pane.searchTop ? 0 : pane.height - height
                width: pane.searchTop ? pane.width : Math.min(720, pane.width * 0.64)
                height: 34
                spacing: Theme.gap
                Box {
                    Layout.preferredWidth: wLabel.implicitWidth + 24
                    Text { id: wLabel; anchors.centerIn: parent; text: ">wallpaper"; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.accent }
                }
                Box {
                    Layout.fillWidth: true
                    border.color: search.activeFocus ? Theme.accent : Theme.muted
                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        font { family: Theme.fontFamily; pixelSize: 13 }
                        color: Theme.fg
                        onTextChanged: { root.filter = text.toLowerCase().trim(); root.sel = 0; previewTimer.restart() }
                        Keys.onPressed: e => root.key(e)
                        Text {
                            visible: !search.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search by name"
                            font: search.font
                            color: Theme.dim
                        }
                    }
                }
                Box {
                    visible: !pane.searchTop
                    Layout.preferredWidth: wKeys.implicitWidth + 24
                    Text { id: wKeys; anchors.centerIn: parent; text: "← → pick · enter apply · esc close"; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.dim }
                }
            }
        }
    }

    Component {
        id: stripView
        ListView {
            id: strip
            orientation: ListView.Horizontal
            spacing: 14
            interactive: false
            model: root.shown
            currentIndex: root.sel
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 125
            preferredHighlightEnd: width / 2 + 125
            highlightMoveDuration: 320

            delegate: WallCard {
                // fade out towards the screen edges, like the demo's masked row
                readonly property real cx: x + width / 2 - strip.contentX
                width: picked ? 250 : 200
                height: implicitHeight
                y: (strip.height - height) / 2
                opacity: Math.max(0, Math.min(1, Math.min(cx, strip.width - cx) / (strip.width * 0.12)))
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }
        }
    }

    Component {
        id: sideView
        ListView {
            spacing: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            currentIndex: root.sel
            highlightMoveDuration: 200
            delegate: WallCard {
                width: ListView.view.width
                height: implicitHeight
            }
        }
    }

    Component {
        id: gridView
        GridView {
            id: grid
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            currentIndex: root.sel
            highlightMoveDuration: 200
            cellWidth: (width + 12) / root.cols
            cellHeight: (cellWidth - 12) * 9 / 16 + 50 + 12
            delegate: Item {
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                WallCard {
                    modelData: parent.modelData
                    index: parent.index
                    width: parent.width - 12
                    height: parent.height - 12
                }
            }
        }
    }
}
