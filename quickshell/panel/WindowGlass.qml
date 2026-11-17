import QtQuick
import Quickshell
import Quickshell.Io

// The window glass values in ~/.config/hypr/rice-settings.lua, the file Settings > Windows writes
// and hyprland.lua applies after its own values. Same file and format, so the quick panel's
// theme tab and that page always agree: every `key = number` line is read, and all of them
// are written back, so keys this tab does not know (from a newer settings page) are kept.
Item {
    id: glass

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/rice-settings.lua"
    // hyprland.lua's own values, used until the file has its own (as Settings > Windows)
    readonly property var defaults: ({active_opacity: 0.94, inactive_opacity: 0.88, blur_size: 6, border_size: 2})
    readonly property var order: ["active_opacity", "inactive_opacity", "blur_size", "border_size"]
    property var values: Object.assign({}, defaults)

    function has(key) {
        return key in values;
    }
    function set(key, v) {
        const next = Object.assign({}, values);
        next[key] = v;
        values = next;
        saveTimer.restart();
    }
    function setMany(kv) {
        values = Object.assign({}, values, kv);
        saveTimer.restart();
    }
    function isDefault() {
        return order.every(k => Math.abs(values[k] - defaults[k]) < 0.005);
    }
    function save() {
        const r = v => Math.round(v * 100) / 100;
        const keys = order.concat(Object.keys(values).filter(k => order.indexOf(k) < 0));
        settingsFile.setText("-- Written by the rice settings window (Quickshell). hyprland.lua applies this after its own values.\n"
            + "return {\n" + keys.map(k => "    " + k + " = " + r(values[k]) + ",\n").join("") + "}\n");
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    FileView {
        id: settingsFile
        path: glass.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const next = Object.assign({}, glass.defaults), re = /^\s*(\w+)\s*=\s*(-?[\d.]+)/gm, t = text();
            let m;
            while ((m = re.exec(t)) !== null)
                next[m[1]] = parseFloat(m[2]);
            glass.values = next;
        }
        // file removed (a settings reset): back to hyprland.lua's values, so the next slider
        // move does not write the old ones back
        onLoadFailed: glass.values = Object.assign({}, glass.defaults)
    }
    // write once the slider rests, so dragging does not reload Hyprland on every step
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: glass.save()
    }
}
