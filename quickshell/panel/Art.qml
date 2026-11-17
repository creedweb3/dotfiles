import QtQuick
import QtQuick.Effects
import "../common"

// Cover art of the current track; the wallpaper stands in when the player has none.
// Settings > Panels > media player (Prefs.mstyle):
//   poster  the cover fills the square (default)
//   disc    a round cover in an accent ring, turning while music plays
//   vinyl   a black record with the cover as its label, turning while music plays, a texture
//           pressed into it (Settings > Panels > vinyl, Prefs.vtex: auto picks one per track
//           title) and a tonearm that swings onto the record while playing
Rectangle {
    id: root

    readonly property string art: Sys.player && Sys.player.trackArtUrl ? Sys.player.trackArtUrl : Theme.wallpaperPath ? "file://" + Theme.wallpaperPath : ""
    readonly property string style: Prefs.mstyle
    readonly property bool playing: Sys.player !== null && Sys.player.isPlaying
    readonly property string title: Sys.player ? Sys.player.trackTitle || "" : ""

    // vinyl texture; "auto" until Prefs has the vtex setting
    readonly property var textures: ["smoke", "nebula", "ink", "lava", "frost"]
    readonly property string vtex: Prefs.spec.vtex ? Prefs.vtex : "auto"
    readonly property int seed: {
        let h = 7;
        for (let i = 0; i < title.length; i++)
            h = (h * 31 + title.charCodeAt(i)) % 2147483647;
        return h || 7;
    }
    readonly property string texture: vtex === "auto" ? textures[seed % textures.length] : vtex

    color: Theme.panel
    clip: true

    Image {
        visible: root.style === "poster"
        anchors.fill: parent
        source: root.style === "poster" ? root.art : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }

    // disc and vinyl: a round thing that turns while playing
    Item {
        id: round
        visible: root.style !== "poster"
        readonly property real d: Math.min(root.width, root.height) * 0.86
        width: d
        height: d
        anchors.centerIn: parent

        RotationAnimation on rotation {
            running: round.visible && root.playing
            loops: Animation.Infinite
            from: round.rotation
            to: round.rotation + 360
            duration: root.style === "vinyl" ? 6000 : 12000
        }

        // vinyl: the record with faint grooves
        Rectangle {
            visible: root.style === "vinyl"
            anchors.fill: parent
            radius: width / 2
            color: "#101012"
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)
            // the texture: value noise in the palette's colours, between the label and the rim.
            // Drawn small and scaled up, so a new track costs a few milliseconds.
            Canvas {
                id: tex
                readonly property int n: 96
                width: n
                height: n
                scale: parent.width / n
                transformOrigin: Item.TopLeft
                readonly property var key: [root.texture, root.seed, Theme.accent, Theme.accent2, Theme.dim, round.visible]
                onKeyChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (!round.visible || root.style !== "vinyl")
                        return;
                    const img = ctx.createImageData(n, n), px = img.data, acc = new Float32Array(n * n * 4);
                    const rgb = c => [c.r, c.g, c.b], A = rgb(Theme.accent), B = rgb(Theme.accent2), D = rgb(Theme.dim), W = [1, 1, 1];
                    // hashed lattice value noise, smoothed, summed over octaves
                    const hash = (x, y, s) => {
                        let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0;
                        h = (h ^ (h >>> 13)) * 1274126177 | 0;
                        return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
                    };
                    const noise = (x, y, s) => {
                        const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
                        const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
                        const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s);
                        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
                    };
                    const fbm = (x, y, oct, s, veins) => {
                        let t = 0, amp = 0.5, f = 1;
                        for (let o = 0; o < oct; o++, amp /= 2, f *= 2) {
                            const v = noise(x * f, y * f, s + o);
                            t += amp * (veins ? Math.abs(v * 2 - 1) : v);
                        }
                        return t;
                    };
                    // one layer: noise -> alpha (gain g, bias o) in colour col, painted over the rest
                    const layer = (col, freq, oct, g, o, s, op, veins) => {
                        for (let y = 0; y < n; y++)
                            for (let x = 0; x < n; x++) {
                                const al = Math.max(0, Math.min(1, g * fbm(x * freq, y * freq, oct, s, veins) + o)) * op;
                                const i = (y * n + x) * 4;
                                for (let k = 0; k < 3; k++)
                                    acc[i + k] = acc[i + k] * (1 - al) + col[k] * al;
                                acc[i + 3] = acc[i + 3] * (1 - al) + al;
                            }
                    };
                    const s = root.seed % 97, k = 180 / n;   // frequencies are the demo's, for its 180px record
                    switch (root.texture) {
                    case "smoke":
                        layer(W, 0.03 * k, 4, 1.6, -0.75, s, 0.55, false);
                        break;
                    case "nebula":
                        layer(B, 0.022 * k, 4, 3, -1.1, s, 1, false);
                        layer(D, 0.035 * k, 3, 3, -1.3, s + 7, 0.9, false);
                        layer(W, 0.05 * k, 3, 4, -2.3, s + 11, 0.7, false);
                        for (let i = 0; i < 40; i++) {   // stars
                            const x = Math.floor(hash(i, 1, s) * n), y = Math.floor(hash(i, 2, s) * n), j = (y * n + x) * 4;
                            acc[j] = acc[j + 1] = acc[j + 2] = 1;
                            acc[j + 3] = 0.5 + hash(i, 3, s) * 0.5;
                        }
                        break;
                    case "ink":
                        layer(D, 0.018 * k, 3, -5, 1.5, s, 0.9, true);
                        layer(A, 0.03 * k, 4, 2, -0.9, s + 3, 0.6, false);
                        break;
                    case "lava":
                        layer(A, 0.016 * k, 3, -5, 1.6, s, 1, true);
                        layer(B, 0.02 * k, 3, -7, 1.4, s, 0.9, true);
                        break;
                    case "frost":
                        layer(W, 0.14 * k, 2, 3, -1.7, s, 0.7, false);
                        layer(B, 0.025 * k, 3, 2, -0.9, s + 2, 0.6, false);
                        break;
                    }
                    // keep the ring between the label and the rim
                    const c = n / 2;
                    for (let y = 0; y < n; y++)
                        for (let x = 0; x < n; x++) {
                            const r = Math.hypot(x + 0.5 - c, y + 0.5 - c) / c, i = (y * n + x) * 4;
                            const al = r > 0.97 || r < 0.42 ? 0 : acc[i + 3];
                            px[i] = acc[i] * 255;
                            px[i + 1] = acc[i + 1] * 255;
                            px[i + 2] = acc[i + 2] * 255;
                            px[i + 3] = al * 255;
                        }
                    ctx.putImageData(img, 0, 0);
                }
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property real s: 0.92 - index * 0.09
                    anchors.centerIn: parent
                    width: parent.width * s
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.05)
                }
            }
        }

        // disc: an accent ring
        Rectangle {
            visible: root.style === "disc"
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
        }

        // the cover, cut round: full size inside the ring (disc), a label (vinyl)
        Item {
            id: cover
            readonly property real d: root.style === "vinyl" ? round.d * 0.4 : round.d - 12
            width: d
            height: d
            anchors.centerIn: parent

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.style !== "poster" ? root.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize: Qt.size(cover.width * 2, cover.height * 2)
                visible: false
                layer.enabled: true
            }
            Rectangle {
                id: coverMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: coverImg
                maskEnabled: true
                maskSource: coverMask
            }
            // spindle hole
            Rectangle {
                visible: root.style === "vinyl"
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: "#101012"
            }
        }
    }

    // vinyl: the tonearm, pivoting in the top right corner. At rest it hangs beside the record;
    // while playing it swings in so the head sits on the grooves.
    Item {
        id: arm
        visible: root.style === "vinyl"
        readonly property real len: Math.min(root.width, root.height) * 0.62
        x: root.width - 12
        y: 12
        rotation: root.playing ? 26 : 2
        transformOrigin: Item.TopLeft

        Behavior on rotation {
            NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
        }

        // counterweight behind the pivot
        Rectangle {
            x: -4
            y: -18
            width: 8
            height: 11
            radius: 2
            color: Theme.dim
        }
        // the rod
        Rectangle {
            x: -1.5
            width: 3
            height: arm.len
            radius: 1.5
            color: Theme.alpha(Theme.fg, 0.85)
        }
        // the head, angled in towards the record
        Rectangle {
            x: -5
            y: arm.len - 4
            width: 10
            height: 16
            radius: 2
            rotation: 18
            color: Theme.accent
        }
    }
    // the pivot's base, not turning
    Rectangle {
        visible: root.style === "vinyl"
        x: root.width - 12 - width / 2
        y: 12 - height / 2
        width: 20
        height: 20
        radius: 10
        color: Theme.panel
        border.width: 1
        border.color: Theme.muted
        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: 3.5
            color: Theme.fg
        }
    }
}
