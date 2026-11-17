import QtQuick

// 40 thin accent bars across the music line's width, tallest in the middle (the demo's .mmspec).
// values: bar heights 0..1 (cava); mirror: the bars grow both ways from the middle line.
Item {
    id: bars

    property bool mirror: false
    property real barHeight: 16
    property real s: 1
    property color accent: "#f6f3ec"
    property bool playing: false
    property var values: []

    implicitHeight: barHeight
    implicitWidth: 80 * s

    Row {
        anchors.fill: parent
        spacing: Math.max(0, (bars.width - 40 * 2 * bars.s) / 39)
        Repeater {
            model: 40
            Rectangle {
                required property int index
                readonly property real h: .35 + .65 * Math.sin(Math.PI * (index + .5) / 40)
                readonly property real v: bars.values.length > index ? Math.max(.08, Math.min(1, bars.values[index])) : h
                width: 2 * bars.s
                height: bars.barHeight
                color: bars.accent
                transform: Scale {
                    origin.y: bars.mirror ? bars.barHeight / 2 : bars.barHeight
                    yScale: bars.playing ? v : .15
                    Behavior on yScale { NumberAnimation { duration: bars.playing ? 90 : 600 } }
                }
            }
        }
    }
}
