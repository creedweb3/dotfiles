import QtQuick
import Quickshell
import "../common"
import "../panel"

// Settings > Panels: the look of the pop-ups. Saved to ~/.config/rice/prefs.json
// (common/Prefs.qml); each pop-up uses it the next time it draws.
// "behind blur" turns Hyprland's blur under the rice's panels on or off (Hyprland has one blur
// size, shared with windows); hyprland.lua reads it, so changing it reloads Hyprland.
Column {
    id: page
    spacing: 12

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

    // a number row: slider and value
    component PrefRange: SetRow {
        id: rangeRow
        property string key
        property string unit: ""
        pref: key
        Item {
            width: parent.width
            height: 18
            Slider {
                anchors { left: parent.left; right: valText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                from: Prefs.spec[rangeRow.key][1]
                to: Prefs.spec[rangeRow.key][2]
                step: 1
                value: Prefs[rangeRow.key]
                onMoved: v => Prefs.set(rangeRow.key, Math.round(v))
            }
            Text {
                id: valText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 48
                horizontalAlignment: Text.AlignRight
                text: Prefs[rangeRow.key] + rangeRow.unit
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.fg
            }
        }
    }
    component Hint: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.Wrap
        font { family: Theme.fontFamily; pixelSize: 11 }
        color: Theme.dim
    }

    Timer { id: reloadTimer; interval: 400; onTriggered: Quickshell.execDetached(["hyprctl", "reload"]) }
    Connections {
        target: Prefs
        function onSblurChanged() { reloadTimer.restart() }   // hyprland.lua reads it; once the slider rests
    }

    SetCard {
        title: "motion"
        PrefSeg {
            label: "open motion"
            key: "panim"
            options: [["slide", "slide"], ["pixel", "pixel build"], ["both", "both"]]
        }
    }

    SetCard {
        title: "wallpaper picker"
        PrefSeg {
            label: "look"
            key: "wstyle"
            options: [["carousel", "bottom carousel"], ["side", "side column"], ["grid", "grid gallery"]]
        }
    }

    SetCard {
        title: "launcher"
        PrefSeg {
            label: "look"
            key: "rst"
            options: [["list", "list"], ["side", "side"]]
        }
        PrefSeg {
            label: "icons"
            key: "ricon"
            options: [["box", "boxed line"], ["bare", "bare line"], ["circle", "circle"], ["tile", "solid tile"], ["real", "real icons"], ["logo", "logo outlines"]]
        }
        PrefSeg {
            label: "selected"
            key: "rsel"
            options: [["bar", "left bar"], ["fill", "solid fill"], ["arrow", "arrow"]]
        }
        PrefSeg {
            label: "matches"
            key: "rmatch"
            options: [["accent", "accent text"], ["bold", "bold"]]
        }
    }

    SetCard {
        title: "media player"
        PrefSeg {
            label: "style"
            key: "mstyle"
            options: [["disc", "disc"], ["poster", "poster"], ["vinyl", "vinyl"]]
        }
        PrefSeg {
            visible: Prefs.mstyle === "vinyl"
            label: "vinyl"
            key: "vtex"
            options: [["auto", "auto"], ["smoke", "smoke"], ["nebula", "nebula"], ["ink", "ink"], ["lava", "lava"], ["frost", "frost"]]
        }
    }

    SetCard {
        title: "settings window"
        PrefSeg {
            label: "look"
            key: "slook"
            options: [["plain", "plain"], ["soft", "soft"], ["lined", "lined"], ["tab", "tab"]]
        }
    }

    SetCard {
        title: "pop-up panels"
        PrefSeg {
            label: "look"
            key: "plook"
            options: [["plain", "plain"], ["soft", "soft"], ["lined", "lined"], ["tab", "tab"]]
        }
    }

    SetCard {
        title: "notifications"
        PrefSeg {
            label: "colour"
            key: "ntone"
            options: [["tinted", "wallpaper tint"], ["neutral", "neutral"]]
        }
    }

    SetCard {
        title: "admin password"
        action: "try it"
        // a harmless request (runs `true` as root) so the polkit agent shows its card
        onActionClicked: Quickshell.execDetached(["pkexec", "true"])
        PrefSeg {
            label: "look"
            key: "pk"
            options: [["card", "card"], ["corners", "corners"], ["strip", "strip"]]
        }
    }

    SetCard {
        title: "behind open panels"
        PrefSeg {
            label: "depth"
            key: "depth"
            options: [["none", "none"], ["shadow", "shadow"], ["scrim", "dim behind"], ["both", "both"]]
        }
        PrefRange { label: "behind blur"; key: "sblur"; unit: "px" }
        PrefRange { visible: Prefs.scrim; label: "behind dim"; key: "sdim"; unit: "%" }
        Hint { text: "applies to the quick panel, mini player, launcher and wallpaper picker · behind blur: 0 turns it off, any other value blurs at the window blur size (Settings > Windows)" }
    }
}
