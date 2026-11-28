import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../common"
import "Ui.js" as Ui
import "Calc.js" as Calc
import "LaunchRows.js" as LR

// App launcher (tap SUPER). The first character of the search picks the mode, or Tab / the chips:
//   apps  (none)  desktop apps, recent first. A typed path, link, #colour, sum or shell command gets its
//                 own actions on top (open in yazi, kitty here, copy hex/rgb/hsl, run in kitty ...);
//                 → on an app shows what else it can do (its desktop actions, copy command, quit)
//   run   >       rice commands
//   calc  =       calculator with keypad and recent results
//   emoji :       every emoji (unicode-emoji's emoji-test.txt), enter copies
//   clip  ;       clipboard history (cliphist), enter copies the entry again
//   power @       lock, sleep, log out, restart, shut down; the last three need enter twice
// Its look is Settings > Panels > launcher (Prefs.rst, ricon, rsel, rmatch) and behind open
// panels (Prefs.depth, sdim).
Scope {
    id: root

    property string query: ""
    property int sel: 0
    property var recent: []          // desktop entry ids, newest first
    property string armed: ""        // power action waiting for its second enter
    property var clips: []           // cliphist lines: "<id>\t<preview>"
    property var emojis: []          // [glyph, name]
    property var calcHistory: []     // [sum, result]
    property bool calcDone: false    // the shown value is a finished result: a digit starts a new sum
    property var presets: []
    property string preset: ""
    property var acting: null        // the desktop entry whose actions are showing (→ on an app)
    property var fsInfo: ({})        // the last path lookup: {path, kind: dir | file | near | none, entries}
    property var clipSeen: ({})      // cliphist id -> when the launcher first saw it (ms), for "2 min ago"
    readonly property string home: Quickshell.env("HOME")

    readonly property var modes: [["apps", "", "apps"], ["run", ">", "run"], ["calc", "=", "calc"],
        ["emoji", ":", "emoji"], ["clip", ";", "clipboard"], ["power", "@", "power"]]
    readonly property var mode: modes.find(m => m[1] && query.startsWith(m[1])) || modes[0]
    readonly property string raw: query.slice(mode[1].length).trim()   // as typed: paths are case sensitive
    readonly property string q: raw.toLowerCase()
    readonly property var rows: build()
    readonly property var items: rows.filter(r => !r.sec)

    readonly property var power: [
        ["lock", "lock", "lock the screen", "system-lock-screen", false, () => Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/rice-lock\""])],
        ["sleep", "sleep", "suspend, any key wakes it", "system-suspend", false, () => Quickshell.execDetached(["systemctl", "suspend"])],
        ["logout", "log out", "end the Hyprland session", "system-log-out", true, () => Hyprland.dispatch("hl.dsp.exit()")],
        ["restart", "restart", "reboot the PC", "system-reboot", true, () => Quickshell.execDetached(["systemctl", "reboot"])],
        ["off", "shut down", "power off", "system-shutdown", true, () => Quickshell.execDetached(["systemctl", "poweroff"])]]

    readonly property var commands: [
        [">wallpaper", "pick a wallpaper", "preferences-desktop-wallpaper", () => root.ipc("wallpaper")],
        [">settings", "open settings", "preferences-system", () => root.ipc("settings")],
        [">preset", "next anime preset", "preferences-desktop-theme", () => root.nextPreset()],
        [">lock", "lock the screen", "system-lock-screen", () => Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/rice-lock\""])],
        [">screenshot", "region to clipboard", "applets-screenshooter", () => Quickshell.execDetached(["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy"])],
        [">colour", "pick a colour", "color-select", () => Quickshell.execDetached(["hyprpicker", "-a"])],
        [">logout", "end the session", "system-log-out", null],
        [">music", "open the music app", "multimedia-audio-player", () => root.special("music")],
        [">chat", "open the chat app", "internet-chat", () => root.special("chat")]]

    readonly property var keypad: [["C", "fn"], ["(", "fn"], [")", "fn"], ["÷", "op"], ["7", ""], ["8", ""], ["9", ""], ["×", "op"],
        ["4", ""], ["5", ""], ["6", ""], ["−", "op"], ["1", ""], ["2", ""], ["3", ""], ["+", "op"],
        ["0", ""], [".", ""], ["⌫", "fn"], ["=", "eq"]]

    readonly property bool side: Prefs.rst === "side"

    // logo outlines look: the icon theme's one-colour (-symbolic) version where it has one, tinted in the accent
    function icon(name) {
        const sym = Prefs.ricon === "logo" && name ? Quickshell.iconPath(name + "-symbolic", true) : ""
        return sym || Quickshell.iconPath(name, "application-x-executable")
    }
    // typed letters: in the accent (default), or bold with the rest of the name dimmed
    function mark(t, q) {
        if (Prefs.rmatch !== "bold") return Ui.mark(t, q, Theme.accent)
        const i = q ? t.toLowerCase().indexOf(q.toLowerCase()) : -1
        if (i < 0) return Ui.esc(t)
        return Ui.esc(t.slice(0, i)) + "<b><font color=\"" + Theme.fg + "\">" + Ui.esc(t.slice(i, i + q.length)) + "</font></b>" + Ui.esc(t.slice(i + q.length))
    }
    function ipc(target) { Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", target, "toggle"]) }
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", String(text)]) }

    function show(prefix) {
        armed = ""
        win.show()
        input.text = prefix || ""
        sel = 0
        clipProc.running = true
        presetProc.running = true
        Qt.callLater(() => input.forceActiveFocus())
    }
    function hide() { win.open = false }
    function toggle() { win.open ? hide() : show() }

    // ---- rows: {sec} headers, or {t, d, icon | glyph, hk, run, big, risky, armed}
    function build() {
        const m = mode[0], out = []
        const sec = t => out.push({sec: t})
        if (acting) {
            sec(acting.name)
            appActions(acting).forEach(a => out.push(a))
        } else if (m === "apps") {
            const all = DesktopEntries.applications.values
            const smart = smartRows(raw)
            smart.forEach(r => out.push(r))
            if (!q) {
                const rec = recent.map(id => all.find(e => e.id === id)).filter(e => e)
                if (rec.length) { sec("recent"); rec.forEach(e => out.push(appRow(e))) }
                sec("all apps")
                all.filter(e => recent.indexOf(e.id) < 0).sort(byName).forEach(e => out.push(appRow(e)))
            } else {
                const f = all.filter(e => (e.name + " " + e.genericName + " " + e.keywords.join(" ")).toLowerCase().indexOf(q) >= 0)
                    .sort((a, b) => (b.name.toLowerCase().startsWith(q) - a.name.toLowerCase().startsWith(q)) || byName(a, b))
                if (f.length && smart.length) sec("apps")
                f.forEach(e => out.push(appRow(e)))
            }
        } else if (m === "run") {
            sec("commands")
            commands.filter(c => (c[0] + " " + c[1]).indexOf(q) >= 0).forEach(c => out.push({
                t: mark(c[0].slice(1), q), d: c[1], icon: icon(c[2]), hk: "⏎ run",
                keep: !c[3], run: c[3] || (() => powerRun("logout"))}))
        } else if (m === "emoji") {
            sec("emoji")
            emojis.filter(e => e[1].indexOf(q) >= 0).slice(0, 80).forEach(e => out.push({
                t: mark(e[1], q), d: "emoji", glyph: e[0], hk: "⏎ copy", run: () => copy(e[0])}))
        } else if (m === "clip") {
            sec("clipboard")
            const now = Date.now()
            clips.filter(c => c.toLowerCase().indexOf(q) >= 0).slice(0, 100).forEach(c => {
                const id = c.slice(0, c.indexOf("\t")), text = c.slice(c.indexOf("\t") + 1), kind = LR.clipKind(text)
                out.push({t: mark(text, q), d: clipSeen[id] ? LR.ago(now - clipSeen[id]) : "",
                    swatch: kind === "swatch" ? text : "", icon: kind === "swatch" ? "" : icon(LR.CLIP_ICONS[kind]),
                    hk: "⏎ copy", run: () => clipCopy(c)})
            })
        } else if (m === "power") {
            sec("power")
            power.filter(p => p[1].indexOf(q) >= 0).forEach(p => {
                const on = armed === p[0]
                out.push({t: mark(p[1], q), d: on ? "press ⏎ again to " + p[1] : p[2], icon: icon(p[3]),
                    hk: on ? "⏎ confirm" : p[4] ? "⏎⏎" : "⏎", risky: p[4], armed: on, keep: true, run: () => powerRun(p[0])})
            })
        }
        let n = 0
        out.forEach(r => { if (!r.sec) r.ii = n++ })  // position among the selectable rows
        return out
    }
    function byName(a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 }
    function appRow(e) {
        return {t: mark(e.name, q), d: e.genericName || e.comment || "", icon: icon(e.icon), hk: "⏎ open  →", entry: e, run: () => launch(e)}
    }

    // ---- smart input (demo smartRows): the first kind that fits wins: path, link, colour, sum, command
    function smartRows(t) {
        if (!t) return []
        const rows = []
        const row = (title, d, ic, hk, act, extra) => rows.push(Object.assign({t: Ui.esc(title), d: d, icon: icon(ic), hk: hk, run: act}, extra || {}))
        if (LR.isPath(t)) {
            const p = LR.normPath(t, home), f = fsInfo.path === p ? fsInfo : null
            if (!f) return rows  // still looking (the lookup runs a moment after typing)
            const abs = LR.absPath(p, home)
            if (f.kind === "dir") {
                const dp = p.endsWith("/") ? p : p + "/", da = LR.absPath(dp, home)
                row(dp, "open in yazi", "folder-open", "⏎ open", () => run(["kitty", "-e", "yazi", da]))
                row("open in file manager", "the default app for folders", "system-file-manager", "", () => run(["xdg-open", da]))
                row("open kitty here", "terminal in this folder", "utilities-terminal", "", () => run(["kitty", "--directory", da]))
                row("copy path", dp, "edit-copy", "", () => copy(dp))
                f.entries.slice(0, 40).forEach(e => fillRow(rows, dp + e, e, "in " + dp, e.endsWith("/") ? "folder" : LR.fileIcon(e)))
            } else if (f.kind === "file") {
                const dir = LR.dirOf(p)
                row(p, "open with the default app", LR.fileIcon(p), "⏎ open", () => run(["xdg-open", abs]))
                row("show in folder", dir, "folder-open", "", () => run(["kitty", "-e", "yazi", abs]))
                row("open in editor", "$EDITOR (nvim)", "accessories-text-editor", "", () => run(["sh", "-c", "exec kitty -e \"${EDITOR:-nvim}\" \"$1\"", "sh", abs]))
                row("copy path", p, "edit-copy", "", () => copy(p))
            } else {
                const dir = LR.dirOf(p), base = p.slice(dir.length).toLowerCase()
                const near = f.kind === "near" && base ? f.entries.filter(e => e.toLowerCase().startsWith(base)) : []
                if (near.length) near.slice(0, 40).forEach(e => fillRow(rows, dir + e, dir + e, e.endsWith("/") ? "folder" : "file", e.endsWith("/") ? "folder" : LR.fileIcon(e)))
                else {
                    row("no such file or folder", p, "edit-find", "", () => {}, {keep: true})
                    if (f.kind === "near") {
                        const dp = p.replace(/\/?$/, "/")
                        row("create folder", dp, "folder-new", "", () => run(["sh", "-c", "mkdir -p -- \"$1\" && notify-send -a launcher 'folder created' \"$2\"", "sh", LR.absPath(dp, home), dp]))
                        if (base) row("create file", p, "document-new", "", () => run(["sh", "-c", "touch -- \"$1\" && notify-send -a launcher 'file created' \"$2\"", "sh", abs, p]))
                    }
                }
            }
        } else if (LR.isUrl(t)) {
            const u = LR.fullUrl(t)
            row(t, "open in the browser", "web-browser", "⏎ open", () => run(["xdg-open", u]))
            row("copy link", u, "edit-copy", "", () => copy(u))
        } else if (LR.isHex(t)) {
            const c = LR.colourForms(t)
            ;[["copy hex", "⏎ copy"], ["copy rgb", ""], ["copy hsl", ""]].forEach((x, i) =>
                rows.push({t: Ui.esc(c[i]), d: x[0], swatch: c[0], hk: x[1], run: () => copy(c[i])}))
        } else if (Calc.isSum(t) && Calc.evaluate(t) !== null) {
            const sum = Calc.evaluate(t)
            rows.push({t: "= " + sum, d: Calc.pretty(t), icon: icon("accessories-calculator"), hk: "⏎ copy", big: true,
                run: () => { saveSum(t, sum); copy(sum) }})
        } else if (LR.isCommand(t)) {
            // the typed command goes to bash as one argument: it runs as typed, in a terminal that stays open
            row(t, "run in kitty", "utilities-terminal", "⏎ run", () => run(["kitty", "--hold", "bash", "-c", t]))
            row("copy command", t, "edit-copy", "", () => copy(t))
        }
        return rows
    }
    // a folder entry: enter or tab puts it in the search, so the next level shows
    function fillRow(rows, full, title, d, ic) {
        rows.push({t: Ui.esc(title), d: d, icon: icon(ic), hk: "tab", fill: full, keep: true, run: () => complete(full)})
    }
    function complete(text) { input.text = text; input.cursorPosition = text.length; input.forceActiveFocus() }
    function run(argv) { Quickshell.execDetached(argv) }
    function lookPath() {
        if (mode[0] !== "apps" || !LR.isPath(raw)) return
        const p = LR.normPath(raw, home)
        fsProc.running = false
        fsProc.target = p
        fsProc.command = ["sh", "-c", "p=$1; if [ -d \"$p\" ]; then echo dir; ls -1Ap -- \"$p\" 2>/dev/null | head -n 60; "
            + "elif [ -e \"$p\" ]; then echo file; else d=$(dirname -- \"$p\"); "
            + "if [ -d \"$d\" ]; then echo near; ls -1Ap -- \"$d\" 2>/dev/null | head -n 400; else echo none; fi; fi",
            "sh", LR.absPath(p, home)]
        fsProc.running = true
    }

    // ---- per-app actions (→): open, the desktop entry's own actions, copy its command, quit its windows
    function windowsOf(e) {
        const ids = [e.id, e.startupClass, e.id.split(".").pop()].filter(x => x).map(x => String(x).toLowerCase())
        return ToplevelManager.toplevels.values.filter(w => ids.indexOf(String(w.appId).toLowerCase()) >= 0)
    }
    function appActions(e) {
        const cmd = Array.from(e.command).join(" ")
        const out = [{t: "open", d: e.name, icon: icon(e.icon), hk: "⏎", run: () => launch(e)}]
        Array.from(e.actions || []).forEach(a => out.push({t: Ui.esc(a.name), d: e.name, icon: icon(a.icon || e.icon), hk: "⏎", run: () => a.execute()}))
        out.push({t: "copy launch command", d: cmd, icon: icon("edit-copy"), hk: "⏎", run: () => copy(cmd)})
        const wins = windowsOf(e)
        if (wins.length) out.push({t: wins.length > 1 ? "quit all windows" : "quit", d: wins.length + " open", icon: icon("window-close"),
            hk: "⏎", risky: true, run: () => wins.forEach(w => w.close())})
        return out
    }
    function openActs() {
        const r = items[sel]
        if (!r || !r.entry) return
        acting = r.entry
        sel = 0
    }

    // ---- music / chat: show their special workspace, starting the default app first when it has no window
    // there. The app is Settings > Apps' choice (Prefs dmusic / dchat), else Spotify / Vesktop; Hyprland's
    // window rule sends it to the special workspace.
    function special(k) {
        const ws = Hyprland.workspaces.values.find(w => w.name === "special:" + k)
        if (!ws || ws.toplevels.values.length === 0) {
            const want = String((k === "music" ? Prefs.dmusic : Prefs.dchat) || (k === "music" ? "spotify" : "vesktop")).toLowerCase()
            const apps = DesktopEntries.applications.values
            const e = apps.find(x => x.id.toLowerCase() === want || x.id.toLowerCase() === want + ".desktop" || x.name.toLowerCase() === want)
                || apps.find(x => x.id.toLowerCase().indexOf(want) >= 0)
            if (want === "mpd") run(Prefs.command("dmusic").split(" "))
            else if (e) e.execute()
            else run([want])
        }
        Hyprland.dispatch('hl.dsp.workspace.toggle_special("' + k + '")')
    }

    function launch(e) {
        recent = [e.id].concat(recent.filter(x => x !== e.id)).slice(0, 4)
        recentFile.setText(recent.join("\n"))
        if (e.runInTerminal) Quickshell.execDetached({command: ["kitty", "-e"].concat(Array.from(e.command)), workingDirectory: e.workingDirectory || Quickshell.env("HOME")})
        else e.execute()
    }
    function clipCopy(line) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", line])
    }
    function nextPreset() {
        if (!presets.length) return
        const next = presets[(presets.indexOf(preset) + 1) % presets.length]
        Quickshell.execDetached(Ui.presetCommand(next))
    }
    // Log out, restart and shut down wait for a second enter (3 s), the others run at once.
    function powerRun(k) {
        const p = power.find(x => x[0] === k)
        if (p[4] && armed !== k) {
            armed = k
            armTimer.restart()
            if (mode[0] !== "power") input.text = "@"
            Qt.callLater(() => sel = Math.max(0, items.findIndex(r => r.armed)))  // items: plain JS objects
            return
        }
        armed = ""
        hide()
        p[5]()
    }
    function saveSum(sum, value) {
        if (!Calc.isSum(sum) || String(sum) === String(value)) return
        calcHistory = [[sum, value]].concat(calcHistory.filter(h => h[0] !== sum)).slice(0, 3)
    }

    function activate(i) {
        const r = items[i]
        if (!r) return
        if (!r.keep) hide()
        r.run()
    }

    // calculator: the keypad types into the search; = keeps the result to chain on
    function calcKey(c) {
        const sum = input.text.slice(1)
        if (c === "C") input.text = "="
        else if (c === "⌫") input.text = "=" + sum.slice(0, -1)
        else if (c === "=") {
            const v = Calc.evaluate(sum)
            if (v !== null) { saveSum(sum, v); input.text = "=" + v; calcDone = true; input.forceActiveFocus(); return }
        } else {
            const ch = {"÷": "/", "×": "*", "−": "-"}[c] || c
            input.text = "=" + (calcDone && /[\d.(]/.test(ch) ? "" : sum) + ch
        }
        calcDone = false
        input.forceActiveFocus()
    }

    function key(e) {
        const n = items.length
        if (acting && (e.key === Qt.Key_Escape || e.key === Qt.Key_Left)) { acting = null; sel = 0 }
        else if (e.key === Qt.Key_Escape) hide()
        else if (e.key === Qt.Key_Right && !acting && input.cursorPosition === input.text.length && items[sel] && items[sel].entry) openActs()
        else if (e.key === Qt.Key_Tab && items[sel] && items[sel].fill) complete(items[sel].fill)
        else if (e.key === Qt.Key_Down) { if (n) sel = Math.min(n - 1, sel + 1) }
        else if (e.key === Qt.Key_Up) { if (n) sel = Math.max(0, sel - 1) }
        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            const i = modes.indexOf(mode), step = e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier) ? modes.length - 1 : 1
            input.text = modes[(i + step) % modes.length][1]
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (mode[0] === "calc") {
                const sum = input.text.slice(1), v = Calc.evaluate(sum)
                if (v !== null) { saveSum(sum, v); copy(v); hide() }
            } else activate(sel)
        } else return
        e.accepted = true
    }

    onQueryChanged: {
        sel = 0
        acting = null
        if (mode[0] === "apps" && LR.isPath(raw)) fsTimer.restart()
        if (armed && mode[0] !== "power") armed = ""
        // the emoji list is read the first time emoji mode opens
        if (mode[0] === "emoji" && !emojiFile.path) emojiFile.path = "/usr/share/unicode/emoji/emoji-test.txt"
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        // open straight in one mode (apps, run, calc, emoji, clip, power), as the demo's deck and power button do
        function open(mode: string): void {
            const m = root.modes.find(x => x[0] === mode)
            root.show(m ? m[1] : "")
        }
    }

    Timer { id: armTimer; interval: 3000; onTriggered: root.armed = "" }
    Timer { id: fsTimer; interval: 120; onTriggered: root.lookPath() }

    Process {  // path lookup for the smart rows; the path is an argument, never part of the script
        id: fsProc
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x)
                root.fsInfo = {path: fsProc.target, kind: lines[0] || "none", entries: lines.slice(1)}
            }
        }
    }
    FileView {  // when each clipboard entry was first seen (cliphist keeps no times)
        id: clipSeenFile
        path: Quickshell.statePath("clip-seen.json")
        printErrors: false
        onLoaded: { try { root.clipSeen = JSON.parse(text()) || {} } catch (e) { root.clipSeen = {} } }
    }
    function noteClips(lines) {
        const now = Date.now(), seen = {}
        lines.forEach(c => { const id = c.slice(0, c.indexOf("\t")); seen[id] = clipSeen[id] || now })
        clipSeen = seen
        clipSeenFile.setText(JSON.stringify(seen))
    }

    FileView {
        id: recentFile
        path: Quickshell.statePath("launcher-recent")
        printErrors: false  // missing until the first launch
        onLoaded: root.recent = text().split("\n").filter(x => x)
    }
    FileView {  // loaded the first time emoji mode opens
        id: emojiFile
        onLoaded: {
            const out = []
            for (const line of text().split("\n")) {
                const m = /; fully-qualified\s+# (\S+) E\d+\.\d+ (.+)$/.exec(line)
                if (m) out.push([m[1], m[2].toLowerCase()])
            }
            root.emojis = out
        }
    }
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x)
                root.noteClips(lines)
                root.clips = lines
            }
        }
    }
    Process {
        id: presetProc
        command: Ui.presetListCommand
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(x => x)
                root.presets = lines.filter(x => x[0] !== "=")
                root.preset = (lines.find(x => x[0] === "=") || "=").slice(1)
            }
        }
    }

    OverlayWindow {
        id: win
        name: "launcher"
        dim: Prefs.scrimAlpha
        onDismissed: root.hide()

        Rectangle {
            id: card
            // list: a centred box; side: a column along the left edge, under the bar
            anchors.centerIn: root.side ? undefined : parent
            anchors.left: root.side ? parent.left : undefined
            anchors.top: root.side ? parent.top : undefined
            anchors.leftMargin: 14
            anchors.topMargin: 48
            width: root.side ? 380 : 520
            height: root.side ? parent.height - 48 - 14 : col.implicitHeight + 4
            color: Theme.glass
            border { color: Theme.accent; width: 2 }
            layer.enabled: Prefs.shadow
            layer.effect: PanelShadow {}
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: col
                x: 2; y: 2
                width: parent.width - 4
                height: root.side ? parent.height - 4 : implicitHeight
                spacing: 0

                GridLayout {  // symbol and search: side by side, or the symbol above (side look)
                    Layout.fillWidth: true
                    Layout.margins: 14
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: root.side ? 22 : 14
                    columns: root.side ? 1 : 2
                    columnSpacing: 12
                    rowSpacing: 12
                    Symbol {
                        size: root.side ? 76 : 26
                        Layout.alignment: root.side ? Qt.AlignHCenter : Qt.AlignVCenter
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        Layout.leftMargin: root.side ? 10 : 0
                        Layout.rightMargin: root.side ? 10 : 0
                        Rectangle {  // side look: the search sits in an outlined field
                            visible: root.side
                            z: -1
                            anchors { fill: parent; leftMargin: -10; rightMargin: -10; topMargin: -7; bottomMargin: -7 }
                            color: "transparent"
                            border.color: input.activeFocus ? Theme.accent : Theme.muted
                        }
                        font { family: Theme.fontFamily; pixelSize: 15 }
                        color: Theme.fg
                        selectionColor: Ui.alpha(Theme.accent, 0.4)
                        clip: true
                        onTextChanged: {
                            // typing = at the end of a sum works like the keypad's =
                            const t = text
                            if (t.length > 2 && t[0] === "=" && t.endsWith("=")) {
                                const sum = t.slice(1, -1), v = Calc.evaluate(sum)
                                text = v === null ? "=" + sum : "=" + v
                                if (v !== null) root.saveSum(sum, v)
                            }
                            root.query = text
                        }
                        Keys.onPressed: e => root.key(e)
                        Text {
                            visible: !input.text
                            text: "search apps"
                            font: input.font
                            color: Theme.dim
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.muted }

                Flow {  // mode chips (they wrap in the narrower side look)
                    Layout.fillWidth: true
                    Layout.margins: 8
                    Layout.leftMargin: 12
                    spacing: 4
                    Repeater {
                        model: root.modes
                        Rectangle {
                            required property var modelData
                            readonly property bool on: root.mode[0] === modelData[0]
                            width: chipText.implicitWidth + 18
                            height: chipText.implicitHeight + 6
                            color: "transparent"
                            border.color: on ? Theme.accent : "transparent"
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: Ui.esc(parent.modelData[2]) + (parent.modelData[1]
                                    ? " <font color=\"" + Ui.mix(parent.on ? Theme.accent : Theme.dim, Theme.bg, 0.55) + "\">" + Ui.esc(parent.modelData[1]) + "</font>" : "")
                                textFormat: Text.StyledText
                                font { family: Theme.fontFamily; pixelSize: 11 }
                                color: parent.on ? Theme.accent : chipArea.containsMouse ? Theme.fg : Theme.dim
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { input.text = parent.modelData[1]; input.forceActiveFocus() }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.muted }

                // calculator: display, keypad, recent results
                ColumnLayout {
                    id: calcBox
                    visible: root.mode[0] === "calc"
                    Layout.fillWidth: true
                    Layout.margins: 10
                    spacing: 6
                    readonly property var value: Calc.evaluate(root.q)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: display.implicitHeight + 20
                        color: "transparent"
                        border.color: Theme.muted
                        ColumnLayout {
                            id: display
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: root.q ? Calc.pretty(root.q) + " =" : " "
                                font { family: Theme.fontFamily; pixelSize: 12 }
                                color: Theme.dim
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: calcBox.value === null ? (root.q ? "…" : "0") : String(calcBox.value)
                                font { family: Theme.fontFamily; pixelSize: 32; weight: Font.DemiBold }
                                color: calcBox.value === null && root.q ? Theme.dim : Theme.fg
                            }
                        }
                    }
                    Grid {
                        Layout.fillWidth: true
                        columns: 4
                        spacing: 4
                        Repeater {
                            model: root.keypad
                            Rectangle {
                                required property var modelData
                                width: (col.width - 20 - 12) / 4
                                height: 38
                                color: modelData[1] === "eq" ? Theme.accent : "transparent"
                                border.color: modelData[1] === "eq" || padArea.containsMouse ? Theme.accent : Theme.muted
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData[0]
                                    font { family: Theme.fontFamily; pixelSize: parent.modelData[1] === "op" ? 17 : 13; bold: parent.modelData[1] === "eq" }
                                    color: parent.modelData[1] === "eq" ? Theme.bg : parent.modelData[1] === "op" ? Theme.accent
                                        : parent.modelData[1] === "fn" ? Theme.dim : Theme.fg
                                }
                                MouseArea { id: padArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.calcKey(parent.modelData[0]) }
                            }
                        }
                    }
                    Text {
                        visible: root.calcHistory.length > 0
                        text: "RECENT"
                        font { family: Theme.fontFamily; pixelSize: 10; letterSpacing: 3 }
                        color: Theme.dim
                    }
                    Repeater {
                        model: root.calcHistory
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text { text: Calc.pretty(parent.modelData[0]) + " ="; font { family: Theme.fontFamily; pixelSize: 12 } color: Theme.dim }
                            Item { Layout.fillWidth: true }
                            Text { text: String(parent.modelData[1]); font { family: Theme.fontFamily; pixelSize: 12 } color: Theme.fg }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { input.text = "=" + parent.modelData[1]; input.forceActiveFocus() }
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    visible: root.mode[0] !== "calc"
                    Layout.fillWidth: true
                    Layout.fillHeight: root.side
                    Layout.preferredHeight: root.side ? -1 : Math.min(contentHeight, 360) + 12
                    Layout.margins: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.rows
                    readonly property int selRow: root.rows.findIndex(r => r.ii === root.sel)
                    onSelRowChanged: if (selRow >= 0) positionViewAtIndex(selRow, ListView.Contain)

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property var r: modelData
                        readonly property bool picked: r.ii === root.sel
                        readonly property color tone: r.armed || (r.risky && picked) ? Theme.crit : Theme.accent
                        // selected row: Prefs.rsel arrow (default) / bar (tint + left line) / fill (solid)
                        readonly property bool filled: picked && Prefs.rsel === "fill" && !r.armed
                        readonly property color ink: filled ? Theme.bg : Theme.fg
                        width: list.width
                        height: r.sec ? secText.implicitHeight + 14 : r.big ? 56 : 44

                        Text {
                            id: secText
                            visible: !!row.r.sec
                            x: 10; y: 10
                            text: (row.r.sec || "").toUpperCase()
                            font { family: Theme.fontFamily; pixelSize: 10; letterSpacing: 3 }
                            color: Theme.dim
                        }
                        Rectangle {  // selected row, "left bar" and "solid fill" looks
                            visible: row.picked && !row.r.sec && !row.r.armed && Prefs.rsel !== "arrow"
                            anchors.fill: parent
                            color: Prefs.rsel === "fill" ? row.tone : Ui.alpha(row.tone, 0.16)
                            Rectangle { width: 2; height: parent.height; color: row.tone; visible: Prefs.rsel === "bar" }
                        }
                        Rectangle {  // armed power action: tinted in the warning colour
                            visible: !!row.r.armed
                            anchors.fill: parent
                            color: Ui.alpha(Theme.crit, 0.18)
                            Rectangle { width: 2; height: parent.height; color: Theme.crit }
                        }
                        RowLayout {
                            visible: !row.r.sec
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 12
                            Text {  // the selected row's marker (arrow look)
                                visible: Prefs.rsel === "arrow"
                                text: "▸"
                                Layout.preferredWidth: 8
                                Layout.rightMargin: -6
                                opacity: row.picked ? 1 : 0
                                font.pixelSize: 12
                                color: row.tone
                            }
                            Rectangle {  // icon, framed as Prefs.ricon: real (no frame), logo (accent outline), box, bare, circle, tile
                                readonly property string look: Prefs.ricon
                                readonly property bool framed: look === "box" || look === "circle"
                                Layout.preferredWidth: look === "bare" ? 22 : 30
                                Layout.preferredHeight: 30
                                radius: look === "circle" ? 15 : 0
                                color: look !== "tile" ? "transparent" : row.picked ? (row.filled ? Theme.bg : Theme.accent) : Ui.alpha(Theme.fg, 0.1)
                                border.width: framed ? 1 : 0
                                border.color: row.filled ? Theme.bg : look === "circle" && row.picked ? Theme.accent : Theme.line
                                Image {
                                    visible: !row.r.glyph && !row.r.swatch
                                    anchors.centerIn: parent
                                    width: parent.look === "real" ? 28 : parent.look === "logo" ? 24 : parent.look === "bare" ? 20 : 18
                                    height: width
                                    sourceSize { width: 56; height: 56 }
                                    source: row.r.icon || ""
                                    asynchronous: true
                                    layer.enabled: parent.look === "logo"
                                    layer.effect: MultiEffect {
                                        colorization: 1.0
                                        colorizationColor: row.filled ? Theme.bg : Theme.accent
                                    }
                                }
                                Rectangle {  // a colour: its swatch
                                    visible: !!row.r.swatch
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    color: row.r.swatch || "transparent"
                                    border { width: 1; color: Theme.line }
                                }
                                Text {
                                    visible: !!row.r.glyph
                                    anchors.centerIn: parent
                                    text: row.r.glyph || ""
                                    font.pixelSize: 20
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    // solid fill: the match colours would vanish on the accent, so drop them
                                    text: row.filled ? (row.r.t || "").replace(/<\/?font[^>]*>/g, "") : row.r.t || ""
                                    textFormat: Text.StyledText
                                    elide: Text.ElideRight
                                    font { family: Theme.fontFamily; pixelSize: row.r.big ? 24 : 13; weight: Font.Medium }
                                    color: row.r.armed ? Theme.crit : row.filled ? Theme.bg
                                        : row.picked && Prefs.rsel === "arrow" ? row.tone
                                        : Prefs.rmatch === "bold" ? Theme.dim : Theme.fg
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !!row.r.d
                                    text: row.r.d || ""
                                    elide: Text.ElideRight
                                    font { family: Theme.fontFamily; pixelSize: 11 }
                                    color: row.r.armed ? Theme.crit : row.filled ? Theme.bg : Theme.dim
                                }
                            }
                            Text {
                                text: row.r.hk || ""
                                opacity: row.picked ? 1 : 0
                                font { family: Theme.fontFamily; pixelSize: 11 }
                                color: row.r.armed ? Theme.crit : row.filled ? Theme.bg : Theme.dim
                            }
                        }
                        MouseArea {
                            visible: !row.r.sec
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.sel = row.r.ii
                            onClicked: root.activate(row.r.ii)
                        }
                    }
                }
                Text {
                    visible: root.mode[0] !== "calc" && root.items.length === 0
                    Layout.fillWidth: true
                    Layout.margins: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: root.mode[0] === "emoji" && !root.emojis.length ? "emoji list missing: install unicode-emoji"
                        : root.mode[0] === "clip" && !root.clips.length ? "clipboard history is empty (cliphist)"
                        : "no match"
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Theme.dim
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.muted }
                Text {  // key hints
                    Layout.margins: 8
                    Layout.leftMargin: 16
                    textFormat: Text.StyledText
                    text: (root.acting ? [["↑↓", "move"], ["⏎", "run"], ["← esc", "back"]]
                        : [["↑↓", "move"], ["⏎", root.mode[0] === "calc" ? "copy" : "open"]]
                            .concat(root.items[root.sel] && root.items[root.sel].entry ? [["→", "actions"]] : [])
                            .concat([["tab", root.items[root.sel] && root.items[root.sel].fill ? "complete" : "mode"], ["esc", "close"]]))
                        .map(h => "<font color=\"" + Theme.fg + "\">" + h[0] + "</font> " + h[1]).join("&nbsp;&nbsp;&nbsp;&nbsp;")
                    font { family: Theme.fontFamily; pixelSize: 10; letterSpacing: 1 }
                    color: Theme.dim
                }
            }
        }
    }
}
