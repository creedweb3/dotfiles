pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Look settings for the shell (Settings > Bar, Panels, Graphs, Lock screen, Power), saved to ~/.config/rice/prefs.json.
// The defaults are the shell's normal look; a value that is not one of the choices falls back
// to its default, so a hand-edited or outdated file cannot break anything.
// "make default" (Settings, per row) saves the user's own defaults to ~/.config/rice/defaults.json;
// "back to default" and "reset" go to those, "factory reset" clears them and goes to `spec`.
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.config/rice/prefs.json"
    readonly property string defaultsFile: Quickshell.env("HOME") + "/.config/rice/defaults.json"
    property var userDefaults: ({})

    // [default, allowed values] for choices; [default, min, max] for numbers
    readonly property var spec: ({
        marker: ["dimframe", ["frame", "dim", "dimframe", "fill"]],
        gap: [6, 2, 14],
        anim: ["spin", ["spin", "swing", "none"]],
        sysic: ["peek", ["text", "icon", "peek"]],
        wstyle: ["carousel", ["carousel", "side", "grid"]],
        rst: ["list", ["list", "side"]],
        ricon: ["real", ["box", "bare", "circle", "tile", "real", "logo"]],
        rsel: ["arrow", ["bar", "fill", "arrow"]],
        rmatch: ["accent", ["accent", "bold"]],
        mstyle: ["vinyl", ["disc", "poster", "vinyl"]],
        vtex: ["auto", ["auto", "smoke", "nebula", "ink", "lava", "frost"]],
        slook: ["lined", ["plain", "soft", "lined", "tab"]],
        ntone: ["tinted", ["tinted", "neutral"]],
        pk: ["card", ["card", "corners", "strip"]],
        sblur: [9, 0, 12],
        plook: ["lined", ["plain", "soft", "lined", "tab"]],
        depth: ["scrim", ["none", "shadow", "scrim", "both"]],
        sdim: [25, 0, 70],
        gstyle: ["flat", ["flat", "tone", "fade", "led", "cap"]],
        gs: [85, 45, 100],
        // power button (hyprland.lua binds XF86PowerOff; logind must ignore the key, see README)
        pbtn: ["menu", ["menu", "off", "sleep", "nothing"]],
        // default apps the launcher's >music / >chat and SUPER+Return start (Settings > Default apps)
        dterm: ["kitty", ["kitty", "foot", "alacritty"]],
        dmusic: ["spotify", ["spotify", "tidal-hifi", "mpd"]],
        dchat: ["vesktop", ["vesktop", "discord", "telegram-desktop"]],
        // lock screen (the demo's manga lock); scripts/rice-lock reads `locker` with jq
        locker: ["quickshell", ["quickshell", "hyprlock"]],
        mpg: ["grid", ["random", "grid", "slant", "diagonal", "shatter", "cutoff"]],
        mfr: [56, [6, 8, 10, 12, 18, 24, 32, 40, 48, 56, 64, 72, 80]],
        mpick: ["action", ["action", "any"]],
        mink: ["night", ["mono", "accent", "duo", "spot", "riso", "night", "gutter", "colour"]],
        macc: ["time", ["full", "soft", "borders", "panels", "time"]],
        mday: ["mix", ["tag", "plain", "rule", "kanji", "mix"]],
        mdt: ["long", ["long", "short", "num", "iso"]],
        mhint: ["quote", ["off", "quote", "chapter", "rule"]],
        mmus: ["spectrum", ["line", "eq", "ticker", "wave", "spectrum", "eqtick", "spectick", "specline", "mirror",
            "wavebar", "underwave", "wavetick", "eqline"]],
        mlsym: ["off", ["on", "off"]],
        mlday: ["on", ["on", "off"]],
        mldate: ["on", ["on", "off"]],
        mlquote: ["on", ["on", "off"]],
        mlmusic: ["on", ["on", "off"]],
        mlnotif: ["off", ["on", "off"]],
        mlhint: ["off", ["on", "off"]]
    })

    function valid(k, v) {
        const s = spec[k];
        if (Array.isArray(s[1]))
            return s[1].indexOf(v) >= 0 ? v : s[0];
        const n = Number(v);
        return isFinite(n) ? Math.max(s[1], Math.min(s[2], Math.round(n))) : s[0];
    }
    // the user's default for k (from "make default"), else the factory one
    function def(k) {
        return (k in userDefaults) ? valid(k, userDefaults[k]) : spec[k][0];
    }
    function isDefault(k) {
        return root[k] === def(k);
    }
    // set several keys, writing the file once
    function setMany(obj) {
        let changed = false;
        for (const k in obj) {
            if (!(k in spec))
                continue;
            const nv = valid(k, obj[k]);
            if (adapter[k] !== nv) {
                adapter[k] = nv;
                changed = true;
            }
        }
        // written here, not on adapterUpdated, so loading the file never writes it back
        if (changed)
            prefsFile.writeAdapter();
    }
    function set(k, v) {
        const o = {};
        o[k] = v;
        setMany(o);
    }
    function reset(k) {
        set(k, def(k));
    }
    function resetKeys(keys) {
        const o = {};
        for (const k of keys)
            if (k in spec)
                o[k] = def(k);
        setMany(o);
    }
    function resetAll() {
        resetKeys(Object.keys(spec));
    }
    function makeDefault(k) {
        const d = Object.assign({}, userDefaults);
        d[k] = root[k];
        userDefaults = d;
        defaultsView.setText(JSON.stringify(d, null, 2) + "\n");
    }
    // the command a default-app choice starts (dterm, dmusic, dchat)
    function command(k) {
        return root[k] === "mpd" ? "kitty --class rice-music -e ncmpcpp" : root[k];   // class: hyprland.lua's special:music rule
    }
    // forget the user's defaults and go back to the shell's own look
    function factoryReset() {
        userDefaults = {};
        defaultsView.setText("{}\n");
        const o = {};
        for (const k in spec)
            o[k] = spec[k][0];
        setMany(o);
    }

    // bar
    readonly property string marker: valid("marker", adapter.marker)
    readonly property int gap: valid("gap", adapter.gap)
    readonly property string anim: valid("anim", adapter.anim)
    readonly property string sysic: valid("sysic", adapter.sysic)
    // panels
    readonly property string wstyle: valid("wstyle", adapter.wstyle)
    readonly property string rst: valid("rst", adapter.rst)
    readonly property string ricon: valid("ricon", adapter.ricon)
    readonly property string rsel: valid("rsel", adapter.rsel)
    readonly property string rmatch: valid("rmatch", adapter.rmatch)
    readonly property string mstyle: valid("mstyle", adapter.mstyle)
    readonly property string vtex: valid("vtex", adapter.vtex)
    readonly property string slook: valid("slook", adapter.slook)
    readonly property string ntone: valid("ntone", adapter.ntone)
    readonly property string pk: valid("pk", adapter.pk)
    readonly property int sblur: valid("sblur", adapter.sblur)
    readonly property string plook: valid("plook", adapter.plook)
    readonly property string depth: valid("depth", adapter.depth)
    readonly property int sdim: valid("sdim", adapter.sdim)
    // graphs
    readonly property string gstyle: valid("gstyle", adapter.gstyle)
    readonly property int gs: valid("gs", adapter.gs)
    // system
    readonly property string pbtn: valid("pbtn", adapter.pbtn)
    readonly property string dterm: valid("dterm", adapter.dterm)
    readonly property string dmusic: valid("dmusic", adapter.dmusic)
    readonly property string dchat: valid("dchat", adapter.dchat)
    // lock screen
    readonly property string locker: valid("locker", adapter.locker)
    readonly property string mpg: valid("mpg", adapter.mpg)
    readonly property int mfr: valid("mfr", adapter.mfr)
    readonly property string mpick: valid("mpick", adapter.mpick)
    readonly property string mink: valid("mink", adapter.mink)
    readonly property string macc: valid("macc", adapter.macc)
    readonly property string mday: valid("mday", adapter.mday)
    readonly property string mdt: valid("mdt", adapter.mdt)
    readonly property string mhint: valid("mhint", adapter.mhint)
    readonly property string mmus: valid("mmus", adapter.mmus)
    readonly property string mlsym: valid("mlsym", adapter.mlsym)
    readonly property string mlday: valid("mlday", adapter.mlday)
    readonly property string mldate: valid("mldate", adapter.mldate)
    readonly property string mlquote: valid("mlquote", adapter.mlquote)
    readonly property string mlmusic: valid("mlmusic", adapter.mlmusic)
    readonly property string mlnotif: valid("mlnotif", adapter.mlnotif)
    readonly property string mlhint: valid("mlhint", adapter.mlhint)

    // derived
    readonly property bool scrim: depth === "scrim" || depth === "both"
    readonly property bool shadow: depth === "shadow" || depth === "both"
    readonly property real scrimAlpha: scrim ? sdim / 100 : 0

    // FileView only writes into an existing folder.
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/rice"]
    }

    FileView {
        id: defaultsView
        path: root.defaultsFile
        watchChanges: true
        printErrors: false   // missing until the first "make default"
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.userDefaults = (d && typeof d === "object" && !Array.isArray(d)) ? d : {};
            } catch (e) {
                root.userDefaults = {};
            }
        }
    }

    FileView {
        id: prefsFile
        path: root.file
        watchChanges: true
        printErrors: false   // missing until the first change
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string marker: "dimframe"
            property int gap: 6
            property string anim: "spin"
            property string sysic: "peek"
            property string wstyle: "carousel"
            property string rst: "list"
            property string ricon: "real"
            property string rsel: "arrow"
            property string rmatch: "accent"
            property string mstyle: "vinyl"
            property string vtex: "auto"
            property string slook: "lined"
            property string ntone: "tinted"
            property string pk: "card"
            property int sblur: 9
            property string plook: "lined"
            property string depth: "scrim"
            property int sdim: 25
            property string gstyle: "flat"
            property int gs: 85
            property string pbtn: "menu"
            property string dterm: "kitty"
            property string dmusic: "spotify"
            property string dchat: "vesktop"
            property string locker: "quickshell"
            property string mpg: "grid"
            property int mfr: 56
            property string mpick: "action"
            property string mink: "night"
            property string macc: "time"
            property string mday: "mix"
            property string mdt: "long"
            property string mhint: "quote"
            property string mmus: "spectrum"
            property string mlsym: "off"
            property string mlday: "on"
            property string mldate: "on"
            property string mlquote: "on"
            property string mlmusic: "on"
            property string mlnotif: "off"
            property string mlhint: "off"
        }
    }
}
