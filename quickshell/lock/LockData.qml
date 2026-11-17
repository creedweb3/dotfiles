import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "Manga.js" as Manga

// What the manga lock draws its frames from: the active preset (the one wallust's symbol template
// links to), the manga store's pages.json (written by `manga-frames`), and as a fallback the preset's
// wallpapers. Used by the lock itself and by Settings > Lock screen's preview.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // the store, as manga-frames / fetch_manga.py: $RICE_MANGA_DIR, else $XDG_CACHE_HOME/rice/manga
    readonly property string store: Quickshell.env("RICE_MANGA_DIR")
        || ((Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/rice/manga")

    property string preset: ""
    property var manifest: ({})
    property var walls: []
    // the frames for the active preset ("action" or "any", Prefs.mpick); empty until manga-frames has run
    readonly property var frames: Manga.framePaths(manifest, preset, store, Prefs.mpick)
    readonly property bool hasFrames: frames.length > 0
    // what the panels show: manga frames, else whole wallpapers (shown as close-ups)
    readonly property var pool: hasFrames ? frames : walls
    readonly property var info: Manga.PRESETS[preset] || { label: preset, quote: "" }

    // Re-read the preset and its wallpapers (cheap; run on every lock).
    function refresh() {
        presetProc.running = false
        presetProc.running = true
        pagesFile.reload()
    }

    // First line "=<preset>", then the preset's wallpapers, then the current wallpaper.
    Process {
        id: presetProc
        running: true
        command: ["sh", "-c",
            "l=$(readlink \"$HOME/.config/wallust/templates/symbol.svg\"); p=$(basename \"$(dirname \"$l\")\"); echo \"=$p\"; " +
            "d=$(readlink -f \"$HOME/.config/wallust\")/../presets/$p/wallpapers; " +
            "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort; " +
            "cat \"$HOME/.cache/wall/current\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x.length > 0)
                const head = lines.find(x => x[0] === "=") || "="
                root.preset = head.slice(1)
                const files = lines.filter(x => x[0] === "/")
                root.walls = files.filter((x, i) => files.indexOf(x) === i).map(x => "file://" + x)
            }
        }
    }

    FileView {
        id: pagesFile
        path: root.store + "/pages.json"
        watchChanges: true
        printErrors: false   // missing until manga-frames has run
        onFileChanged: reload()
        onLoaded: {
            try {
                const m = JSON.parse(text())
                root.manifest = (m && typeof m === "object") ? m : {}
            } catch (e) {
                console.warn("lock: pages.json is not valid JSON:", e)
                root.manifest = {}
            }
        }
        onLoadFailed: root.manifest = {}
    }
}
