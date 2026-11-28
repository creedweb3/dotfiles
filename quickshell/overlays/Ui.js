.pragma library
// Small helpers shared by the overlays: colour mixing (the demo's color-mix) and text escaping.

// Theme colours may be strings or colors; Qt.darker(c, 1) turns either into a color.
function col(c) { return Qt.darker(c, 1.0) }

// color-mix(in srgb, c a%, transparent)
function alpha(c, a) { const k = col(c); return Qt.rgba(k.r, k.g, k.b, k.a * a) }

// color-mix(in srgb, a t%, b)
function mix(a, b, t) {
    const x = col(a), y = col(b)
    return Qt.rgba(x.r * t + y.r * (1 - t), x.g * t + y.g * (1 - t), x.b * t + y.b * (1 - t), x.a * t + y.a * (1 - t))
}

function esc(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Rich text with the first match of q in t drawn in colour c (search highlights).
function mark(t, q, c) {
    const i = q ? t.toLowerCase().indexOf(q.toLowerCase()) : -1
    if (i < 0) return esc(t)
    return esc(t.slice(0, i)) + "<font color=\"" + c + "\">" + esc(t.slice(i, i + q.length)) + "</font>" + esc(t.slice(i + q.length))
}

// Switch the anime preset: point wallust's symbol template at the preset's symbol, then re-theme.
// If the current wallpaper is not one of the preset's, switch to its first one (the copy in
// ~/Pictures/wallpapers when there is one), else re-theme from the current wallpaper.
// ~/.config/wallust links to the repo's wallust/, so presets/ sits beside it. `wall` is looked up in
// ~/.local/bin first: the shell started at login does not have it on PATH.
// Argv for Quickshell.execDetached; the preset name is passed as $1, never pasted into the script.
function presetCommand(name) {
    return ["sh", "-c",
        "d=$(readlink -f \"$HOME/.config/wallust\")/..; [ -f \"$d/presets/$1/symbol.svg\" ] || exit 1; " +
        "w=\"$HOME/.local/bin/wall\"; [ -x \"$w\" ] || w=wall; " +
        "ln -sfn \"../../presets/$1/symbol.svg\" \"$HOME/.config/wallust/templates/symbol.svg\" || exit 1; " +
        "cur=$(basename \"$(cat \"$HOME/.cache/wall/current\" 2>/dev/null)\"); " +
        "[ -n \"$cur\" ] && [ -f \"$d/presets/$1/wallpapers/$cur\" ] && exec \"$w\" --restore; " +
        "first=$(find \"$d/presets/$1/wallpapers\" -type f | sort | head -n 1); " +
        "[ -n \"$first\" ] || exec \"$w\" --restore; " +
        "pic=\"$HOME/Pictures/wallpapers/$(basename \"$first\")\"; [ -f \"$pic\" ] || pic=\"$first\"; " +
        "exec \"$w\" \"$pic\"",
        "sh", name]
}

// Lists the presets, then the active one on the last line.
var presetListCommand = ["sh", "-c",
    "d=$(readlink -f \"$HOME/.config/wallust\")/..; for p in \"$d\"/presets/*/symbol.svg; do basename \"$(dirname \"$p\")\"; done; " +
    "echo \"=$(basename \"$(dirname \"$(readlink \"$HOME/.config/wallust/templates/symbol.svg\")\")\")\""]
