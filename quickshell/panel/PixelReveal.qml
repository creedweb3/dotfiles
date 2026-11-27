import QtQuick
import QtQuick.Effects
import "../common"

// Pixel build: what this holds is revealed through a grid of squares that grow in one after
// another, spreading diagonally down and out from `originX` (the bar box that opened it).
// The mask runs only while it plays; once built the content is drawn normally, so text stays sharp.
// Call play() when the panel opens and unplay() when it closes: the squares shrink away from the
// far edges back toward the box. `busy` is true while either runs (keep the window shown till then).
Item {
    id: root

    default property alias content: holder.data
    property real originX: width / 2   // where the build starts, along the top edge
    property real tile: 22
    property int duration: 600
    property real progress: 1          // 0 nothing, 1 fully built
    // the bar: start this frame with a fast-start curve, so it answers the mouse at once
    // (panels wait a frame and ease in, which reads better for a big panel)
    property bool instant: false
    // closing time as a share of the opening time
    property real closeShare: instant ? 1 : 0.6

    readonly property int cols: Math.max(1, Math.ceil(width / tile))
    readonly property int rows: Math.max(1, Math.ceil(height / tile))
    readonly property real originCol: Math.max(0, Math.min(cols - 1, Math.floor(originX / tile)))
    readonly property real span: Math.max(originCol, cols - 1 - originCol) + rows - 1   // the furthest square's step
    readonly property real soft: 4     // how many steps each square takes to grow in

    readonly property bool busy: build.running || unbuild.running || pending

    property bool pending: false   // play() called, starting next frame

    // Taps can come faster than the animation: each call carries on from where it is, in the new
    // direction, at the same speed, so rapid open / close never restarts or drops a tap.
    function unplay() {
        build.stop();
        pending = false;
        unbuild.from = progress;
        // the bar mirrors its build (same time, same fast start); panels close quicker than they open
        unbuild.duration = Math.max(1, Math.round(root.duration * root.closeShare * progress));
        unbuild.start();
    }

    function play() {
        const reversing = unbuild.running || build.running;
        build.stop();
        unbuild.stop();
        if (!reversing)
            progress = 0;   // a fresh open: start from nothing (the value left from last time is stale)
        build.from = progress;
        build.duration = Math.max(1, Math.round(root.duration * (1 - progress)));
        if (instant || reversing) {
            pending = false;
            build.start();
            return;
        }
        pending = true;
        // a fresh panel: start on the next frame, once it and its squares are drawn at 0
        Qt.callLater(() => {
            if (!root.pending)
                return;
            root.pending = false;
            build.start();
        });
    }

    NumberAnimation {
        id: build
        target: root
        property: "progress"
        to: 1
        // even speed from the first square to the last (a fast-start curve made it look like it
        // began halfway)
        easing.type: root.instant ? Easing.OutCubic : Easing.InOutSine
    }

    NumberAnimation {
        id: unbuild
        target: root
        property: "progress"
        to: 0
        easing.type: root.instant ? Easing.OutCubic : Easing.InOutSine
    }

    // The content is drawn normally (sharp) while built. While building or un-building it is hidden
    // and shown through the mask instead. The effect below is made once and kept, only hidden:
    // switching an effect on builds its shader on the spot, which froze the first frames of closing.
    Item {
        id: holder
        anchors.fill: parent
    }
    ShaderEffectSource {
        id: snap
        anchors.fill: holder
        sourceItem: holder
        hideSource: root.progress < 1
        live: root.progress < 1
        visible: false
        textureSize: Qt.size(Math.ceil(width * Theme.uiScale), Math.ceil(height * Theme.uiScale))
    }
    MultiEffect {
        anchors.fill: holder
        source: snap
        visible: root.progress < 1
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.0
    }

    Item {
        id: mask
        width: root.width
        height: root.height
        visible: false
        // the square mask stays rendered and ready (it never changes while the panel is open), so
        // closing starts on the very next frame instead of first rebuilding it
        layer.enabled: true

        Repeater {
            // always made, so none are still being created when the build starts
            model: root.cols * root.rows

            Rectangle {
                required property int index
                readonly property int c: index % root.cols
                readonly property int r: Math.floor(index / root.cols)
                readonly property real step: Math.abs(c - root.originCol) + r
                // 0 -> 1 as the build front passes this square
                readonly property real t: Math.max(0, Math.min(1, (root.progress * (root.span + root.soft) - step) / root.soft))
                x: c * root.tile + (root.tile - width) / 2
                y: r * root.tile + (root.tile - height) / 2
                width: root.tile * (0.35 + 0.67 * t)
                height: width
                color: "black"
                opacity: t > 0.02 ? 1 : 0
            }
        }
    }
}
