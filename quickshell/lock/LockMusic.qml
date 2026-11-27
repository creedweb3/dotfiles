import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../common"

// The lock's music line (the demo's mgMusic): the playing title, prev / play / next, and one accent
// visual — spectrum bars, eq bars, a scrolling ticker or a moving wave — in the chosen style.
// values: 40 bar heights (0..1) from cava; paused, the bars settle low and the ticker and wave stop.
Item {
    id: mus

    property string style: "spectrum"
    property color accent: "#f6f3ec"
    property string title: ""
    property string artist: ""
    property bool playing: false
    property var values: []
    property real s: 1                  // text scale
    signal prev()
    signal toggle()
    signal next()

    readonly property color dimC: "#8a8a8a"
    readonly property color fgC: "#f6f3ec"
    readonly property string label: "<b><font color=\"#f6f3ec\">" + esc(title) + "</font></b>" + (artist ? " · " + esc(artist) : "")

    // spectrum keeps its layout: the title now has two lines (title, artist) and elides cleanly
    readonly property string shown: style

    function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    // rows of parts; c: centred row. Same layouts as the demo's flex rows.
    readonly property var rows: ({
        line: [{ p: ["nt", "tt"], c: true }],
        eq: [{ p: ["eq", "tt", "ctl"] }],
        ticker: [{ p: ["tick", "ctl"] }],
        wave: [{ p: ["tt", "wave", "ctl"] }],
        spectrum: [{ p: ["spec"] }, { p: ["nt", "tt", "ctl"] }],
        eqtick: [{ p: ["eq", "tick", "ctl"] }],
        spectick: [{ p: ["spec"] }, { p: ["nt", "tick", "ctl"] }],
        specline: [{ p: ["spec"] }, { p: ["tt"], c: true }],
        mirror: [{ p: ["mirror"] }, { p: ["tt"], c: true }, { p: ["ctl"], c: true }],
        wavebar: [{ p: ["tt"], c: true }, { p: ["wave"] }, { p: ["ctl"], c: true }],
        underwave: [{ p: ["tt", "ctl"] }, { p: ["wave"] }],
        wavetick: [{ p: ["tick", "ctl"] }, { p: ["wave"] }],
        eqline: [{ p: ["eq", "tt"], c: true }]
    })[shown] || [{ p: ["spec"] }, { p: ["nt", "tt", "ctl"] }]

    implicitHeight: col.implicitHeight

    Text {   // measures the title for the spectrum -> ticker switch
        id: probe
        visible: false
        text: mus.label
        textFormat: Text.StyledText
        font.pixelSize: 12 * mus.s
    }

    Column {
        id: col
        width: parent.width
        spacing: 8 * mus.s
        Repeater {
            model: mus.rows
            Item {
                id: row
                required property var modelData
                width: col.width
                height: rl.implicitHeight
                RowLayout {
                    id: rl
                    spacing: 12 * mus.s
                    width: row.modelData.c ? Math.min(implicitWidth, row.width) : row.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: row.modelData.p
                        Loader {
                            required property string modelData
                            readonly property bool fills: !row.modelData.c && ["tt", "tick", "wave", "spec", "mirror"].indexOf(modelData) >= 0
                            Layout.fillWidth: fills
                            Layout.maximumWidth: modelData === "tt" && row.modelData.p.indexOf("wave") >= 0 ? row.width * .55 : Number.POSITIVE_INFINITY
                            Layout.preferredWidth: fills ? -1 : (item ? item.implicitWidth : 0)
                            Layout.preferredHeight: item ? item.implicitHeight : 0
                            Layout.alignment: Qt.AlignVCenter
                            sourceComponent: ({ tt: ttC, nt: ntC, ctl: ctlC, eq: eqC, tick: tickC, wave: waveC, spec: specC, mirror: mirrorC })[modelData]
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ttC
        // title on its own line, the artists under it, each cut with "…" if too long.
        // (an Item carries the width: a Column's implicitWidth is read-only)
        Item {
            id: ttBox
            readonly property bool centred: !!(parent && parent.parent && parent.parent.parent && parent.parent.parent.modelData && parent.parent.parent.modelData.c)
            implicitWidth: Math.min(Math.max(ttTitle.implicitWidth, ttArtist.implicitWidth), mus.width)
            implicitHeight: ttCol.implicitHeight
            Column {
                id: ttCol
                width: parent.width
                spacing: 2 * mus.s
                Text {
                    id: ttTitle
                    width: parent.width
                    text: mus.title
                    elide: Text.ElideRight
                    horizontalAlignment: ttBox.centred ? Text.AlignHCenter : Text.AlignLeft
                    font { family: Theme.fontFamily; pixelSize: 13 * mus.s; bold: true }
                    color: mus.fgC
                }
                Text {
                    id: ttArtist
                    visible: text !== ""
                    width: parent.width
                    text: mus.artist
                    elide: Text.ElideRight
                    horizontalAlignment: ttBox.centred ? Text.AlignHCenter : Text.AlignLeft
                    font { family: Theme.fontFamily; pixelSize: 11 * mus.s }
                    color: mus.dimC
                }
            }
        }
    }

    Component {
        id: ntC
        Icon { path: Icons.music; size: 16 * mus.s; stroke: 2; color: mus.accent }
    }
    Component {
        id: ctlC
        // previous / play-pause / next as solid shapes, all in one style (the font has no glyphs
        // for ⏮ ⏭, which came out as colour emoji boxes)
        Row {
            Repeater {
                model: [[Icons.prev, "prev"], [mus.playing ? Icons.pause : Icons.play, "toggle"], [Icons.next, "next"]]
                Item {
                    required property var modelData
                    width: 28 * mus.s
                    height: 26 * mus.s
                    Icon {
                        anchors.centerIn: parent
                        path: parent.modelData[0]
                        size: (parent.modelData[1] === "toggle" ? 16 : 13) * mus.s
                        stroke: 1.6
                        filled: true   // solid, like the pause bars, all three alike
                        color: ma.containsMouse ? mus.accent : parent.modelData[1] === "toggle" ? mus.fgC : mus.dimC
                        scale: ma.pressed ? .88 : 1
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mus[parent.modelData[1]]()
                    }
                }
            }
        }
    }
    Component {   // eq: four bars before the title
        id: eqC
        Row {
            spacing: 2 * mus.s
            height: 13 * mus.s
            Repeater {
                model: [.7, 1, .55, .85]
                Rectangle {
                    required property real modelData
                    required property int index
                    readonly property real v: mus.values.length ? Math.min(1, mus.values[index * 10 + 5] * 1.6) : modelData
                    width: 3 * mus.s
                    height: 13 * mus.s
                    color: mus.accent
                    transform: Scale { origin.y: 13 * mus.s; yScale: mus.playing ? Math.max(.2, v) : .15
                        Behavior on yScale { NumberAnimation { duration: mus.playing ? 90 : 600 } } }
                }
            }
        }
    }
    Component {   // spectrum: a full-width row of thin bars, tallest in the middle
        id: specC
        LockBars { mirror: false; barHeight: 16 * mus.s; s: mus.s; accent: mus.accent; playing: mus.playing; values: mus.values }
    }
    Component {
        id: mirrorC
        LockBars { mirror: true; barHeight: 24 * mus.s; s: mus.s; accent: mus.accent; playing: mus.playing; values: mus.values }
    }
    Component {   // ticker: the title scrolls
        id: tickC
        Item {
            implicitHeight: tk.implicitHeight
            implicitWidth: 120 * mus.s
            clip: true
            Text {
                id: tk
                text: (mus.label + "&nbsp;&nbsp;&nbsp;·&nbsp;&nbsp;&nbsp;").repeat(2)
                textFormat: Text.StyledText
                font.pixelSize: 12 * mus.s
                color: mus.dimC
                NumberAnimation on x {
                    from: 0
                    to: -tk.implicitWidth / 2
                    duration: 16000
                    loops: Animation.Infinite
                    paused: !mus.playing
                }
            }
        }
    }
    Component {   // wave: a moving accent wave
        id: waveC
        Item {
            implicitHeight: 12 * mus.s
            implicitWidth: 30 * mus.s
            clip: true
            opacity: .85
            Shape {
                width: 600 * mus.s
                height: 12 * mus.s
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: mus.accent
                    strokeWidth: 1.5 * mus.s
                    scale: Qt.size(mus.s, mus.s)
                    PathSvg { path: "M0 6" + Array.from({ length: 20 }, (_, i) => " q15 " + (i % 2 ? 6 : -6) + " 30 0").join("") }
                }
                NumberAnimation on x {
                    from: 0
                    to: -60 * mus.s
                    duration: 1800
                    loops: Animation.Infinite
                    paused: !mus.playing
                }
            }
        }
    }
}
