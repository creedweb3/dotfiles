import QtQuick
import Quickshell
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
        title: "size"
        SetRow {
            label: "ui size"
            SetSeg {
                options: [["auto", "auto"], ["100", "100%"], ["125", "125%"], ["150", "150%"], ["175", "175%"], ["200", "200%"]]
                value: Prefs.uiscale
                onPicked: v => {
                    if (v === Prefs.uiscale)
                        return;
                    Prefs.set("uiscale", v);
                    // the scale is fixed when Quickshell starts: restart the shell at the new size
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-shell", "--restart"]);
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "bar, panels and pop-ups together; the shell restarts to apply it. auto picks from your screen height."
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    SetCard {
        title: "bar"
        PrefSeg {
            label: "auto-hide"
            key: "bhide"
            options: [["off", "off"], ["auto", "on"]]
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "on: the bar hides and windows use the full height. Touch the top edge of the screen to bring it back; windows shrink smoothly to make room. It also shows for a moment when you switch workspace."
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
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
