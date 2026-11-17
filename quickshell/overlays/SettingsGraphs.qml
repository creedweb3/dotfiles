import QtQuick
import "../common"
import "../panel"

// Settings > Graphs: the style and strength of the meters in the quick panel's system tab,
// the volume / brightness pop-up's level and the sparklines. Saved to ~/.config/rice/prefs.json.
Column {
    id: page
    spacing: 12

    SetCard {
        title: "cpu, meters and progress bars"
        SetRow {
            label: "style"
            pref: "gstyle"
            SetSeg {
                options: [["flat", "flat"], ["tone", "tone"], ["fade", "fade"], ["led", "led"], ["cap", "cap"]]
                value: Prefs.gstyle
                onPicked: v => Prefs.set("gstyle", v)
            }
        }
        SetRow {
            label: "graph strength"
            pref: "gs"
            Item {
                width: parent.width
                height: 18
                Slider {
                    anchors { left: parent.left; right: gsText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    from: Prefs.spec.gs[1]
                    to: Prefs.spec.gs[2]
                    step: 1
                    value: Prefs.gs
                    onMoved: v => Prefs.set("gs", Math.round(v))
                }
                Text {
                    id: gsText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 48
                    horizontalAlignment: Text.AlignRight
                    text: Prefs.gs + "%"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.fg
                }
            }
        }

        // preview: bouncing bars and a meter in the chosen style
        Item {
            width: parent.width
            height: 60
            Row {
                id: preview
                anchors.fill: parent
                spacing: 3
                property real t: 0
                NumberAnimation on t {
                    from: 0; to: 2 * Math.PI
                    duration: 4000
                    loops: Animation.Infinite
                    running: page.visible
                }
                Repeater {
                    model: 32
                    Item {
                        id: col
                        required property int index
                        width: (preview.width - 31 * preview.spacing) / 32
                        height: preview.height
                        GraphFill {
                            vertical: true
                            anchors.bottom: parent.bottom
                            width: col.width
                            height: col.height * (0.12 + 0.8 * Math.abs(Math.sin(preview.t * 3 + col.index * 0.33) * Math.cos(preview.t * 2 + col.index * 0.1)))
                        }
                    }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 8
            color: Theme.alpha(Theme.muted, 0.45)
            GraphFill {
                width: parent.width * 0.64
                height: parent.height
            }
        }
    }
}
