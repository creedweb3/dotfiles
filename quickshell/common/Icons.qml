pragma Singleton
import QtQuick
import Quickshell

// Line icons on a 24 x 24 grid, the same paths the demo draws (Tabler-style strokes).
// Drawn by Icon.qml as one stroked path.
Singleton {
    readonly property string vol0: "M4 9h4l5-4v14l-5-4H4z"
    readonly property string vol1: "M4 9h4l5-4v14l-5-4H4zM16 9a4 4 0 0 1 0 6"
    readonly property string vol: "M4 9h4l5-4v14l-5-4H4zM16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"
    readonly property string volx: "M4 9h4l5-4v14l-5-4H4zM16 9l5 6M21 9l-5 6"
    readonly property string mic: "M9 3h6v11H9zM5 11a7 7 0 0 0 14 0M12 18v3"
    readonly property string micoff: "M9 3h6v11H9zM5 11a7 7 0 0 0 14 0M12 18v3M3 3l18 18"
    readonly property string sun: "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"
    readonly property string moon: "M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"
    readonly property string lock: "M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3"
    readonly property string sleep: moon
    readonly property string logout: "M10 4H5v16h5M15 8l4 4-4 4M19 12H9"
    readonly property string reboot: "M20 12a8 8 0 1 1-2.3-5.7M20 4v4h-4"
    readonly property string power: "M12 3v8M6.3 6.3a8 8 0 1 0 11.4 0"
    readonly property string bt: "M7 7l10 10-5 5V2l5 5L7 17"
    readonly property string slash: "M3 3l18 18"
    readonly property string wired: "M5 14h14v6H5zM9 14v-4h6v4M12 10V4"
    readonly property string battery: "M3 8h15v8H3zM21 11v2"
    readonly property string music: "M9 18V5l11-2v13M9 18a3 3 0 1 1-6 0a3 3 0 1 1 6 0zM20 16a3 3 0 1 1-6 0a3 3 0 1 1 6 0z"
    readonly property string star: "M12 3l2.7 5.6 6.1.8-4.5 4.3 1.1 6.1L12 16.9l-5.4 2.9 1.1-6.1L3.2 9.4l6.1-.8z"
    readonly property string check: "M5 12.5l4.5 4.5L19 7.5"
    readonly property string cross: "M6 6l12 12M18 6L6 18"
    readonly property string undo: "M9 14L4 9l5-5M4 9h10.5a5.5 5.5 0 0 1 0 11H11"
    readonly property string play: "M7 4l13 8-13 8z"
    readonly property string pause: "M7 4h3v16H7zM14 4h3v16h-3z"
    readonly property string next: "M5 5l10 7-10 7zM19 5v14"
    readonly property string prev: "M19 5L9 12l10 7zM5 5v14"
    readonly property string shuffle: "M3 7h4l10 10h4M3 17h4l3-3M14 10l3-3h4M18 4l3 3-3 3M18 14l3 3-3 3"
    readonly property string repeat: "M4 11V9a2 2 0 0 1 2-2h13M16 4l3 3-3 3M20 13v2a2 2 0 0 1-2 2H5M8 20l-3-3 3-3"
    readonly property string thx: "M3 12h3l3-7 4 14 3-7h5"

    // Wi-Fi with 1..3 arcs (signal strength), optionally struck through.
    function wifi(arcs, off) {
        const all = ["M8.5 16a5 5 0 0 1 7 0", "M5 12.5a10 10 0 0 1 14 0", "M2 9a15 15 0 0 1 20 0"];
        return all.slice(0, Math.max(1, Math.min(3, arcs))).join("") + "M11.4 19.5a.6 .6 0 1 0 1.2 0a.6 .6 0 1 0-1.2 0" + (off ? slash : "");
    }

    // Speaker with waves by level, as the demo: none below 34%, one to 66%, two above.
    function volume(level, isMuted) {
        if (isMuted || level <= 0)
            return volx;
        return level >= 67 ? vol : level >= 34 ? vol1 : vol0;
    }
}
