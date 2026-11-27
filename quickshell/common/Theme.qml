pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours, fonts and shared sizes for the whole shell.
// The palette comes from ~/.cache/rice/palette.json, written by `wall` (palette-pick);
// it reloads live when the file changes. Until then a neutral dark palette is used.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/rice"

    property string kind: "mono"
    property color bg: "#0D0D0F"
    property color panel: "#17171A"
    property color muted: "#3F3F45"
    property color dim: "#8E8E96"
    property color fg: "#E6E6EA"
    property color accent: "#E8E8E8"
    property color accent2: "#9E9E9E"
    property color warn: "#E5A84B"
    readonly property color crit: "#E5534B"

    // Outer boxes (bar boxes, panel edges) mix 40% accent into the line, as the demo's
    // default "border tint"; lines inside panels stay plain muted.
    readonly property color line: mix(accent, muted, 0.4)
    // Glass: how much of Hyprland's blur shows through the bar boxes and panels follows
    // Settings > Panels > behind blur (Prefs.sblur 0-12, default 9 -> 61% / 65% fill).
    // At 0 Hyprland does not blur them, so they stay nearly solid.
    readonly property real glassAlpha: Math.max(0.5, 0.92 - Prefs.sblur * 0.03)
    readonly property color boxFill: alpha(panel, glassAlpha - 0.04)
    readonly property color glass: alpha(bg, glassAlpha)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int smallSize: 11
    readonly property int gap: Prefs.gap  // space between bar boxes (Settings > Bar)
    readonly property int boxHeight: 26
    readonly property int barHeight: 30
    readonly property int barTop: 8
    readonly property int barSide: 14
    // Shell size (rice-shell sets QT_SCALE_FACTOR from Settings > Bar > ui size). Everything here is in
    // scaled pixels, but Hyprland's gaps are not, so they shrink by this factor in shell units.
    readonly property real uiScale: Number(Quickshell.env("QT_SCALE_FACTOR")) || 1
    readonly property int popupTop: barTop + barHeight + Math.round(14 / uiScale)   // windows' top edge: bar + Hyprland gaps_out

    // Bumped on every palette or symbol change, so images reload (cache busting).
    property int rev: 0
    readonly property string symbolPath: "file://" + cacheDir + "/symbol.svg?" + rev
    property string wallpaperPath: ""

    function mix(a, b, t) {
        return Qt.rgba(a.r * t + b.r * (1 - t), a.g * t + b.g * (1 - t), a.b * t + b.b * (1 - t), 1);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function applyPalette(text) {
        let p;
        try {
            p = JSON.parse(text);
        } catch (e) {
            console.warn("Theme: palette.json is not valid JSON:", e);
            return;
        }
        const hex = /^#[0-9a-fA-F]{6}$/;
        for (const k of ["bg", "panel", "muted", "dim", "fg", "accent", "accent2", "warn"]) {
            if (typeof p[k] === "string" && hex.test(p[k]))
                root[k] = p[k];
        }
        if (typeof p.kind === "string")
            root.kind = p.kind;
        root.rev++;
    }

    FileView {
        id: paletteFile
        path: root.cacheDir + "/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyPalette(text())
    }

    FileView {
        id: wallFile
        path: root.home + "/.cache/wall/current"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wallpaperPath = text().trim()
    }

    FileView {
        id: symbolFile
        path: root.cacheDir + "/symbol.svg"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.rev++;
        }
    }

    // `qs -c rice ipc call theme reload`: for scripts that replace the files in ways
    // a file watch can miss.
    IpcHandler {
        target: "theme"
        function reload(): void {
            paletteFile.reload();
            wallFile.reload();
            root.rev++;
        }
    }
}
