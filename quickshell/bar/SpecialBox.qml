import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../common"

// One special workspace while a special workspace is showing (the bar swaps its workspace
// numbers for these, as the demo). The showing one is solid accent; started ones (it has
// windows) look like occupied workspaces. Click shows or hides it.
Box {
    id: root

    required property string name
    required property bool occupied
    required property bool current

    readonly property var icons: ({
        music: "M9 18V5l11-2v13M9 18a3 3 0 1 1-6 0a3 3 0 0 1 6 0zM20 16a3 3 0 1 1-6 0a3 3 0 0 1 6 0z",
        chat: "M4 5h16v11H9l-5 4z",
        browser: "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18",
        sysmon: "M3 4h18v12H3zM8 20h8M12 16v4M6 12l3-3 3 3 3-5 3 3"
    })
    readonly property bool framed: occupied && (Prefs.marker === "frame" || Prefs.marker === "dimframe")
    readonly property bool bright: occupied || Prefs.marker === "frame" || Prefs.marker === "fill"

    implicitWidth: 34
    color: current ? Theme.accent : occupied && Prefs.marker === "fill" ? Theme.alpha(Theme.mix(Theme.accent, Theme.panel, 0.3), 0.84) : Theme.boxFill
    border.color: current || framed || hovered ? Theme.edge : Theme.line

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        path: root.icons[root.name] || "M5 5h14v14H5z"
        size: 14
        color: root.current ? Theme.bg : root.bright ? Theme.fg : Theme.alpha(Theme.fg, 0.45)
    }

    // Hyprland's Lua dispatch; names are checked first since they go into Lua source
    onClicked: {
        if (name === "browser" || name === "sysmon")
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-special", name]);
        else if (/^[A-Za-z0-9_-]+$/.test(name))
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${name}")`);
    }
}
