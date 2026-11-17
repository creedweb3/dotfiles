import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Settings > Default apps: which app opens links, folders, images, videos and text files
// (xdg-settings / xdg-mime). The choices are the installed apps of the matching desktop category.
Column {
    id: page
    spacing: 12

    // [key, label, desktop category, mime types]; "browser" goes through xdg-settings.
    readonly property var kinds: [
        ["browser", "browser", "WebBrowser", ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]],
        ["files", "files", "FileManager", ["inode/directory"]],
        ["images", "images", "Viewer", ["image/png", "image/jpeg", "image/webp", "image/gif"]],
        ["video", "video", "Player", ["video/mp4", "video/x-matroska", "video/webm"]],
        ["editor", "text editor", "TextEditor", ["text/plain"]]]
    property var current: ({})   // key -> desktop file id ("firefox.desktop")

    function desktopId(e) { return e.id.endsWith(".desktop") ? e.id : e.id + ".desktop" }
    function choices(category) {
        return DesktopEntries.applications.values.filter(e => e.categories.indexOf(category) >= 0)
            .map(e => [desktopId(e), e.name]).sort((a, b) => a[1].toLowerCase() < b[1].toLowerCase() ? -1 : 1)
    }
    function pick(kind, id) {
        const next = Object.assign({}, current)
        next[kind[0]] = id
        current = next
        if (kind[0] === "browser") Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", id])
        else Quickshell.execDetached(["xdg-mime", "default", id].concat(kind[3]))
    }

    Process {  // what opens each kind now: one line per kind, in the order of `kinds` (empty when unset)
        running: true
        command: ["sh", "-c", "echo \"$(xdg-settings get default-web-browser)\"; for m in inode/directory image/png video/mp4 text/plain; do echo \"$(xdg-mime query default \"$m\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n"), next = {}
                page.kinds.forEach((k, i) => next[k[0]] = (lines[i] || "").trim())
                page.current = next
            }
        }
    }

    SetCard {
        title: "open with"
        Repeater {
            model: page.kinds
            SetRow {
                id: row
                required property var modelData
                label: modelData[1]
                SetSeg {
                    width: parent.width
                    options: page.choices(row.modelData[2])
                    value: page.current[row.modelData[0]] || ""
                    onPicked: v => page.pick(row.modelData, v)
                }
            }
        }
        Text {
            text: "only installed apps of each kind are listed"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }

    // terminal, music and chat: rice settings (Prefs), not xdg. SUPER+Return starts the terminal
    // (hyprland.lua reads it, so it reloads); the launcher's >music and >chat start the other two.
    SetCard {
        title: "start with"
        Repeater {
            model: [["dterm", "terminal", [["kitty", "kitty"], ["foot", "foot"], ["alacritty", "Alacritty"]]],
                ["dmusic", "music", [["spotify", "Spotify"], ["tidal-hifi", "TIDAL"], ["mpd", "mpd (ncmpcpp)"]]],
                ["dchat", "chat", [["vesktop", "Vesktop"], ["discord", "Discord"], ["telegram-desktop", "Telegram"]]]]
            SetRow {
                id: prow
                required property var modelData
                label: modelData[1]
                pref: modelData[0]
                SetSeg {
                    options: prow.modelData[2]
                    value: Prefs[prow.modelData[0]]
                    onPicked: v => Prefs.set(prow.modelData[0], v)
                }
            }
        }
        Text {
            text: "the launcher's >music and >chat open these"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
    }
    // hyprland.lua reads dterm from prefs.json: reload once the file is written
    Timer { id: reloadTimer; interval: 400; onTriggered: Quickshell.execDetached(["hyprctl", "reload"]) }
    Connections {
        target: Prefs
        function onDtermChanged() { reloadTimer.restart() }
    }
}
