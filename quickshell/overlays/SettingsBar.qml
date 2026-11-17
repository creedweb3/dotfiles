import QtQuick
import "../common"
import "../panel"

// Settings > Bar: how the top bar looks. Saved to ~/.config/rice/prefs.json (common/Prefs.qml);
// the bar changes at once.
Column {
    id: page
    spacing: 12

    // a choice row: label, then the options as chips
    component PrefSeg: SetRow {
        id: segRow
        property string key
        property var options: []
        pref: key
        SetSeg {
            options: segRow.options
            value: Prefs[segRow.key]
            onPicked: v => Prefs.set(segRow.key, v)
        }
    }

    SetCard {
        title: "workspaces"
        PrefSeg {
            label: "open marker"
            key: "marker"
            options: [["frame", "frame"], ["dim", "dim"], ["dimframe", "dim + frame"], ["fill", "fill"]]
        }
        SetRow {
            id: gapRow
            label: "bar gap"
            pref: "gap"
            Item {
                width: parent.width
                height: 18
                Slider {
                    anchors { left: parent.left; right: gapText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    from: Prefs.spec.gap[1]
                    to: Prefs.spec.gap[2]
                    step: 1
                    value: Prefs.gap
                    onMoved: v => Prefs.set("gap", Math.round(v))
                }
                Text {
                    id: gapText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 48
                    horizontalAlignment: Text.AlignRight
                    text: Prefs.gap + "px"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.fg
                }
            }
        }
    }

    SetCard {
        title: "centre symbol"
        PrefSeg {
            label: "hover animation"
            key: "anim"
            options: [["spin", "spin"], ["swing", "swing"], ["none", "none"]]
        }
    }

    SetCard {
        title: "sound · bluetooth · wi-fi"
        PrefSeg {
            label: "show"
            key: "sysic"
            options: [["text", "icon + text"], ["icon", "icon only"], ["peek", "expand on hover"]]
        }
    }
}
