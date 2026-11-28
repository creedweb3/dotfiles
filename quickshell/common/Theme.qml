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

    // Outer edges (bar boxes, panel edges) are drawn exactly like the window borders Hyprland draws
    // (hypr/hyprland.lua, colours from wallust/templates/hypr.lua): the same width in screen pixels
    // and the same colours, following Settings > Windows / Theme tab > border width and border tint
    // (~/.config/hypr/rice-settings.lua). Lines inside panels stay plain muted, 1px.
    property real winBorder: 2      // border_size, screen pixels
    property real winTint: 0.4      // border_tint, 0-1
    // in shell units: Hyprland's border is not scaled by the ui size, so this cancels the scale out
    readonly property real border: snap(winBorder / uiScale)
    // focused window: the accent at Hyprland's alpha (ee)
    readonly property color edge: alpha(accent, 0xee / 255)
    // other windows: the tint's share of accent (alpha ee) mixed into muted (alpha 66), alpha too
    readonly property color line: {
        const t = Math.max(0, Math.min(1, winTint)), m = mix(accent, muted, t);
        return Qt.rgba(m.r, m.g, m.b, 0x66 / 255 + (0xee / 255 - 0x66 / 255) * t);
    }
    // Glass: how much of Hyprland's blur shows through the bar boxes and panels follows
    // Settings > Panels > behind blur (Prefs.sblur 0-12, default 9 -> 61% / 65% fill).
    // At 0 Hyprland does not blur them, so they stay nearly solid.
    readonly property real glassAlpha: Math.max(0.5, 0.92 - Prefs.sblur * 0.03)
    readonly property color boxFill: alpha(panel, glassAlpha - 0.04)
    readonly property color glass: alpha(bg, glassAlpha)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int smallSize: 11
    // Snap a size to whole screen pixels. The shell runs at a fractional scale (125%: 1 unit = 1.25px),
    // so a 26-unit box is 32.5px: the half pixel was cut off the bottom border, which drew 1px against
    // 2px on the other sides. Sizes and positions that set where an outline lands go through these.
    function snap(v) { return Math.round(v * uiScale) / uiScale }
    function snapUp(v) { return Math.ceil(v * uiScale - 0.001) / uiScale }
    // an even number of pixels, so a centred panel has the same gap on both sides
    function snapEven(v) { return Math.round(v * uiScale / 2) * 2 / uiScale }
    // where a box of size `size` starts to sit centred in `room`, on a whole pixel
    function centre(room, size) { return snap((room - size) / 2) }
    readonly property real gap: snap(Prefs.gap)  // space between bar boxes (Settings > Bar)
    // 26 units, rounded down to whole pixels (32px at 125%): the bar's reserved space only comes in
    // whole units, and 32px is the height that puts windows exactly gaps_out below the boxes.
    // Worked out from the live gap: the bar reserves space in whole shell units (barZone), which
    // Hyprland rounds down to pixels; the box height is whatever makes that land exactly on the
    // boxes' last row, so windows sit gaps_out below them for any gap and ui scale (~26 units tall).
    readonly property int barZone: {
        const s = uiScale, m = Math.floor(Math.floor(barTop) * s);
        return Math.ceil((winGapsOut + Math.floor(26 * s) - m) / s);
    }
    readonly property real boxHeight: (Math.floor(Math.floor(Math.floor(barTop) * uiScale) + barZone * uiScale) - winGapsOut) / uiScale
    // The window grid, read live from Hyprland (hyprctl getoption), so the shell follows whatever
    // hyprland.lua / rice-settings.lua set: nothing here assumes 14px gaps or 2px borders.
    // Screen pixels; Hyprland's gaps are not scaled by the ui size.
    property real winGapsOut: 14    // general:gaps_out (until the first read)
    property real winGapsIn: 6      // general:gaps_in
    // the bar is exactly as tall as its boxes, so the boxes sit gaps_out from the screen top
    // as from the windows below and the screen sides
    readonly property real barHeight: boxHeight
    readonly property real barTop: snap(winGapsOut / uiScale)
    // in line with the windows: gaps_out in shell units (the ui scale is cancelled out)
    readonly property real barSide: snap(winGapsOut / uiScale)
    // Shell size (rice-shell sets QT_SCALE_FACTOR from Settings > Bar > ui size). Everything here is in
    // scaled pixels, but Hyprland's gaps are not, so they shrink by this factor in shell units.
    readonly property real uiScale: Number(Quickshell.env("QT_SCALE_FACTOR")) || 1
    readonly property real popupTop: barTop + barHeight + snap(winGapsOut / uiScale)   // windows' top edge: bar + gaps_out

    // Bumped on every palette or symbol change, so images reload (cache busting).
    property int rev: 0
    readonly property string symbolPath: "file://" + cacheDir + "/symbol.svg?" + rev
    property string wallpaperPath: ""
    // its file name: a wallpaper may be set from its preset's folder or from the copy in
    // ~/Pictures/wallpapers, so lists of the latter match the current one by name
    readonly property string wallpaperName: wallpaperPath.slice(wallpaperPath.lastIndexOf("/") + 1)

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
        id: winSettings
        path: root.home + "/.config/hypr/rice-settings.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            hyprRead.restart();   // hyprland.lua reloads after the file changes: read the live values then
        }
        onLoaded: {
            const t = text(), num = k => {
                const m = new RegExp("^\\s*" + k + "\\s*=\\s*(-?[\\d.]+)", "m").exec(t);
                return m ? parseFloat(m[1]) : NaN;
            };
            // border width comes live from Hyprland (hyprProc below); the tint has no Hyprland option
            const tint = num("border_tint");
            root.winTint = isNaN(tint) ? 0.4 : tint;
        }
        // no file (settings reset): hyprland.lua's own values, read live from Hyprland
        onLoadFailed: {
            root.winTint = 0.4;
            hyprRead.restart();
        }
    }

    // Live window-grid values from Hyprland: at start, after rice-settings.lua changes, and on request
    // (rice-gapcheck --watch calls `theme sync` when it sees the shell out of step).
    function syncHypr() { hyprProc.running = true }
    Timer { id: hyprRead; interval: 600; onTriggered: root.syncHypr() }
    Process {
        id: hyprProc
        running: true
        command: ["sh", "-c", "for o in gaps_out gaps_in border_size; do hyprctl getoption general:$o -j; echo; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vals = this.text.split("\n").filter(l => l.trim()).map(l => {
                    try {
                        const j = JSON.parse(l);
                        const v = j.int !== undefined ? j.int : String(j.css || j.custom || "").split(" ")[0];
                        return parseFloat(v);
                    } catch (e) { return NaN }
                });
                if (!isNaN(vals[0])) root.winGapsOut = vals[0];
                if (!isNaN(vals[1])) root.winGapsIn = vals[1];
                if (!isNaN(vals[2])) root.winBorder = vals[2];
            }
        }
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
        // match Hyprland's live border_size (rice-gapcheck --watch calls this when the bar's outlines
        // and the window borders drift apart, e.g. after a border change that skipped rice-settings.lua)
        function setBorder(px: real): void {
            if (px >= 0 && px <= 20)
                root.winBorder = px;
        }
        // re-read gaps and border from Hyprland
        function sync(): void {
            root.syncHypr();
        }
    }
}
