.pragma library
// The shortcuts the sheet (SUPER+/) and the settings window show. Keep in step with hypr/hyprland.lua.
// Each row: [action, keys, run, id]. run is what Enter does from the sheet:
//   {d: "..."}   a Hyprland dispatcher, Lua form (hl.dsp...; Hyprland 0.55+)
//   {c: [...]}   a command (argv, no shell)
//   {ipc: "x"}   toggle another rice overlay (qs -c rice ipc call x toggle)
//   null         nothing to run (the shortcut needs a held key or the mouse)
// id names the bind in hyprland.lua (K("id", ...)); rows with an id can be changed in Settings > Shortcuts,
// which writes ~/.config/hypr/rice-keys.lua. Rows without one use several keys, the mouse or a media key.
var groups = [
    ["apps", [
        ["app launcher", "SUPER+D", {ipc: "launcher"}, "launcher"],
        ["terminal", "SUPER+Return", {c: ["kitty"]}, "terminal"],
        ["files", "SUPER+E", {c: ["kitty", "-e", "yazi"]}, "files"],
        ["browser", "SUPER+B", {c: ["brave"]}, "browser"],
        ["settings", "SUPER+S", {ipc: "settings"}, "settings"],
        ["audio settings", "CTRL+ALT+V", {c: ["pavucontrol"]}, "audio"]]],
    ["windows", [
        ["close window", "SUPER+Q", {d: "hl.dsp.window.close()"}, "close"],
        ["fullscreen", "SUPER+F", {d: 'hl.dsp.window.fullscreen({ action = "toggle" })'}, "fullscreen"],
        ["float", "SUPER+V", {d: 'hl.dsp.window.float({ action = "toggle" })'}, "float"],
        ["move focus", "SUPER+arrows", null],
        ["resize", "SUPER+right drag", null],
        ["switch window", "ALT+Tab", {d: "hl.dsp.window.cycle_next()"}],
        ["narrower / wider", "SUPER+-", null],
        ["shorter / taller", "SUPER+SHIFT+-", null],
        ["maximize (keep bar)", "SUPER+ALT+F", {d: 'hl.dsp.window.fullscreen({ mode = "maximized" })'}, "maximize"],
        ["pin on all workspaces", "SUPER+P", {d: "hl.dsp.window.pin()"}, "pin"],
        ["centre window", "CTRL+SUPER+\\", {d: "hl.dsp.window.center()"}, "center"],
        ["picture-in-picture", "SUPER+ALT+\\", null, "pip"]]],
    ["workspaces", [
        ["go to workspace", "SUPER+1..9, 0", {d: "hl.dsp.focus({ workspace = 1 })"}],
        ["move window to workspace", "SUPER+SHIFT+1..9", {d: "hl.dsp.window.move({ workspace = 1 })"}],
        ["send window, stay here", "SUPER+ALT+1..9", null],
        ["previous / next", "CTRL+SUPER+arrows", {d: 'hl.dsp.focus({ workspace = "+1" })'}],
        ["next / previous", "SUPER+scroll", {d: 'hl.dsp.focus({ workspace = "e+1" })'}],
        ["music (special)", "SUPER+M", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-special\" music"]}, "music"],
        ["chat (special)", "SUPER+X", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-special\" chat"]}, "chat"],
        ["browser (special)", "SUPER+SHIFT+B", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-special\" browser"]}, "browserspecial"],
        ["system monitor (special)", "SUPER+`", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-special\" sysmon"]}, "sysmon"]]],
    ["media", [
        ["play / pause", "XF86AudioPlay", {c: ["playerctl", "play-pause"]}],
        ["volume up / down", "XF86AudioRaiseVolume", {c: ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"]}],
        ["mute", "XF86AudioMute", {c: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]}],
        ["mic mute", "SUPER+U", {c: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]}, "micmute"],
        ["play / pause (keys)", "CTRL+SUPER+Space", {c: ["playerctl", "play-pause"]}, "playpause"],
        ["next track", "CTRL+SUPER+=", {c: ["playerctl", "next"]}, "next"],
        ["previous track", "CTRL+SUPER+-", {c: ["playerctl", "previous"]}, "prev"]]],
    ["system", [
        ["quick panel", "SUPER+C", {ipc: "panel"}, "panel"],
        ["pick wallpaper", "SUPER+W", {ipc: "wallpaper"}, "wallpaper"],
        ["screenshot region", "SUPER+SHIFT+S", {c: ["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy"]}, "screenshot"],
        ["colour picker", "SUPER+SHIFT+C", {c: ["hyprpicker", "-a"]}, "picker"],
        ["lock", "SUPER+L", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-lock\""]}, "lock"],
        ["shortcuts sheet", "SUPER+/", null, "sheet"],
        ["clipboard history", "SUPER+SHIFT+V", {c: ["qs", "-c", "rice", "ipc", "call", "launcher", "open", "clip"]}, "clipboard"],
        ["emoji", "SUPER+.", {c: ["qs", "-c", "rice", "ipc", "call", "launcher", "open", "emoji"]}, "emoji"],
        ["power menu", "CTRL+ALT+Delete", {c: ["qs", "-c", "rice", "ipc", "call", "launcher", "open", "power"]}, "session"],
        ["screenshot screen", "Print", null, "screenfull"],
        ["record screen", "CTRL+ALT+R", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-record\""]}, "record"],
        ["record region", "SUPER+SHIFT+ALT+R", {c: ["sh", "-c", "exec \"$HOME/.local/bin/rice-record\" region"]}, "recordregion"],
        ["clear notifications", "CTRL+ALT+C", {c: ["qs", "-c", "rice", "ipc", "call", "notifs", "clear"]}, "clearnotifs"],
        ["sleep", "SUPER+SHIFT+L", {c: ["systemctl", "suspend"]}, "sleep"]]]]

var MEDIA = {XF86AudioPlay: ["play"], XF86AudioRaiseVolume: ["vol +", "vol −"], XF86AudioMute: ["mute"]}
var NAME = {Return: "⏎", Enter: "⏎", arrows: "← ↑ ↓ →", "1..9, 0": "1 – 0", "1..9": "1 – 9", Delete: "del", Print: "prt", SHIFT: "shift", CTRL: "ctrl", ALT: "alt"}
// short labels for the lit keys; anything else uses the first word of the action
var SHORT = {"app launcher": "run", settings: "setup", browser: "web", terminal: "term", "close window": "close", fullscreen: "full",
    "music (special)": "music", "chat (special)": "chat", "browser (special)": "web", "system monitor (special)": "btop", "mic mute": "mic", "quick panel": "panel", "pick wallpaper": "wall",
    "shortcuts sheet": "help", "move focus": "focus"}

// The drawn keyboard: every row is 15 units. [label, width]; right-hand duplicates carry a trailing
// space so only the left ones light up.
var ROWS = [
    [["`", 1], ["1", 1], ["2", 1], ["3", 1], ["4", 1], ["5", 1], ["6", 1], ["7", 1], ["8", 1], ["9", 1], ["0", 1], ["-", 1], ["=", 1], ["⌫", 2]],
    [["tab", 1.5], ["q", 1], ["w", 1], ["e", 1], ["r", 1], ["t", 1], ["y", 1], ["u", 1], ["i", 1], ["o", 1], ["p", 1], ["[", 1], ["]", 1], ["\\", 1.5]],
    [["caps", 1.8], ["a", 1], ["s", 1], ["d", 1], ["f", 1], ["g", 1], ["h", 1], ["j", 1], ["k", 1], ["l", 1], [";", 1], ["'", 1], ["⏎", 2.2]],
    [["shift", 2.3], ["z", 1], ["x", 1], ["c", 1], ["v", 1], ["b", 1], ["n", 1], ["m", 1], [",", 1], [".", 1], ["/", 1], ["shift ", 2.7]],
    [["ctrl", 1.5], ["super", 1.5], ["alt", 1.5], ["space", 6.1], ["alt ", 1.5], ["fn", 1.4], ["ctrl ", 1.5]]]

// "SUPER+SHIFT+S" -> {sup: true, k: ["shift", "s"]}
function parse(s) {
    if (MEDIA[s]) return {sup: false, k: MEDIA[s]}
    let p = s.split("+")
    const sup = p[0] === "SUPER"
    if (sup) p = p.slice(1)
    return {sup: sup, k: p.map(x => NAME[x] || x.toLowerCase())}
}

function hit(q, a, b) { return !q || (a + " " + b).toLowerCase().indexOf(q) >= 0 }

function matches(q) {
    let out = []
    for (const g of groups) out = out.concat(g[1].filter(r => hit(q, r[0], r[1])))
    return out
}

function rowsOf(group, q) {
    const g = groups.find(x => x[0] === group)
    return g ? g[1].filter(r => hit(q, r[0], r[1])) : []
}

// Keys lit while super is held: super plus one key, no other modifier, matching the search.
// The picked row also lights its own keys (with shift).
function lit(q, pick) {
    const M = {}
    for (const g of groups) for (const r of g[1]) {
        const p = parse(r[1])
        if (!p.sup || p.k.length !== 1 || !hit(q, r[0], r[1])) continue
        const k = p.k[0], l = SHORT[r[0]] || r[0].split(" ")[0]
        if (k === "1 – 0") { for (let i = 1; i <= 9; i++) M["" + i] = "ws " + i; M["0"] = "ws 10" }
        else if (k === "← ↑ ↓ →") { for (const x of ["←", "↑", "↓", "→"]) M[x] = l }
        else if (k.length === 1 || k === "⏎") M[k] = l
    }
    if (pick) for (const k of parse(pick[1]).k) {
        if (k === "shift") M.shift = ""
        else if ((k.length === 1 || k === "⏎") && M[k] === undefined) M[k] = ""
    }
    return M
}

// Run a row's action. hyprland and quickshell are the Hyprland and Quickshell singletons.
function run(row, hyprland, quickshell) {
    const r = row && row[2]
    if (!r) return
    if (r.d) hyprland.dispatch(r.d)
    else if (r.c) quickshell.execDetached(r.c)
    else if (r.ipc) quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", r.ipc, "toggle"])
}

// ---- Changing shortcuts (Settings > Shortcuts). The keys shown here are the display form, "SUPER+SHIFT+/";
// hyprland.lua and rice-keys.lua use the Hyprland form, "SUPER + SHIFT + slash".

// Default keys by id, taken before any change is applied.
var DEFAULTS = {}
for (const g of groups) for (const r of g[1]) if (r[3]) DEFAULTS[r[3]] = r[1]

// Binds in hyprland.lua the sheet does not list; a changed shortcut must not take them either.
var RESERVED = [["THX app picker", "SUPER+A"], ["toggle split", "SUPER+J"], ["exit Hyprland", "SUPER+SHIFT+E"]]

// Display key -> Hyprland key name (xkb keysym).
var SYM = {"/": "slash", ",": "comma", ".": "period", ";": "semicolon", "'": "apostrophe", "[": "bracketleft",
    "]": "bracketright", "-": "minus", "=": "equal", "`": "grave", "\\": "backslash", Space: "space"}
// With shift held Qt reports the shifted symbol; binds use the unshifted key (US layout).
var UNSHIFT = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
    "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`"}
// Qt key codes for the named keys a shortcut may use (values from Qt::Key).
var NAMED = {0x01000001: "Tab", 0x01000002: "Tab", 0x01000003: "BackSpace", 0x01000004: "Return", 0x01000005: "Return",
    0x01000006: "Insert", 0x01000007: "Delete", 0x01000009: "Print", 0x01000010: "Home", 0x01000011: "End",
    0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down", 0x01000016: "Prior", 0x01000017: "Next"}
// Shift, Control, Meta, Alt, CapsLock, NumLock, Super_L, Super_R, Hyper_L, Hyper_R, AltGr: wait for the real key.
var MODKEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000024, 0x01000025, 0x01000053, 0x01000054,
    0x01000056, 0x01000057, 0x01001103]

function toHypr(combo) { return combo.split("+").map(k => SYM[k] || k).join(" + ") }
function fromHypr(s) {
    const back = {}
    for (const k in SYM) back[SYM[k]] = k
    return s.split("+").map(x => x.trim()).map(k => back[k] || k).join("+")
}

// A key press while recording -> {combo} | {err} | null (a modifier alone: keep waiting).
// No modifier held: SUPER is added, as in the demo.
function comboOf(key, modifiers) {
    if (MODKEYS.indexOf(key) >= 0) return null
    let k = NAMED[key]
    if (!k && key >= 0x01000030 && key <= 0x01000052) k = "F" + (key - 0x01000030 + 1)
    if (!k && key > 0x20 && key < 0x7f) {
        const c = String.fromCharCode(key)
        k = UNSHIFT[c] || c.toUpperCase()
    }
    if (!k && key === 0x20) k = "Space"
    if (!k) return {err: "that key can't be used for a shortcut"}
    const mods = []
    if (modifiers & 0x10000000) mods.push("SUPER")
    if (modifiers & 0x04000000) mods.push("CTRL")
    if (modifiers & 0x08000000) mods.push("ALT")
    if (modifiers & 0x02000000) mods.push("SHIFT")
    // SHIFT or ALT alone would take a key away from typing in every app
    const sup = mods.indexOf("SUPER") >= 0, ctl = mods.indexOf("CTRL") >= 0
    if (mods.length && !sup && !ctl) return {err: "hold SUPER or CTRL too, or that key stops typing"}
    return {combo: (mods.length ? mods : ["SUPER"]).concat([k]).join("+")}
}

// The action already on combo (other than row), or "".
function clash(row, combo) {
    for (const g of groups) for (const r of g[1]) if (r !== row && r[1] === combo) return r[0]
    for (const r of RESERVED) if (r[1] === combo) return r[0]
    if (/^SUPER\+[0-9]$/.test(combo)) return "go to workspace"
    if (/^SUPER\+SHIFT\+[0-9]$/.test(combo)) return "move window to workspace"
    if (/^SUPER\+(Left|Right|Up|Down)$/.test(combo)) return "move focus"
    if (/^SUPER\+SHIFT\+(Left|Right|Up|Down)$/.test(combo)) return "move window"
    return ""
}

// rice-keys.lua text -> {id: "SUPER + K"}; unknown ids and odd values are dropped.
function readFile(text) {
    const out = {}, re = /\["(\w+)"\]\s*=\s*"([A-Za-z0-9_ +]+)"/g
    let m
    while ((m = re.exec(text || "")) !== null) if (DEFAULTS[m[1]] !== undefined) out[m[1]] = m[2]
    return out
}

// Put the changed keys into the rows (the sheet and the settings page read them from there).
function setOverrides(map) {
    for (const g of groups) for (const r of g[1]) if (r[3]) r[1] = map[r[3]] ? fromHypr(map[r[3]]) : DEFAULTS[r[3]]
}

// The changes as they stand, Hyprland form, only where they differ from the default.
function overrides() {
    const out = {}
    for (const g of groups) for (const r of g[1]) if (r[3] && r[1] !== DEFAULTS[r[3]]) out[r[3]] = toHypr(r[1])
    return out
}

function fileText(map) {
    let s = "-- Written by Settings > Shortcuts. Each line moves one shortcut away from its default;\n" +
        "-- delete a line (or the file) to put it back. hyprland.lua reads this on every reload.\nreturn {\n"
    for (const id in map) s += '    ["' + id + '"] = "' + map[id] + '",\n'
    return s + "}\n"
}
