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

    readonly property int cols: Math.max(1, Math.ceil(width / tile))
    readonly property int rows: Math.max(1, Math.ceil(height / tile))
    readonly property real originCol: Math.max(0, Math.min(cols - 1, Math.floor(originX / tile)))
    readonly property real span: Math.max(originCol, cols - 1 - originCol) + rows - 1   // the furthest square's step
    readonly property real soft: 4     // how many steps each square takes to grow in

    readonly property bool busy: build.running || unbuild.running || pending

    property bool pending: false   // play() called, starting next frame

    function unplay() {
        build.stop();
        pending = false;
        unbuild.from = progress;
        unbuild.duration = Math.round(root.duration * 0.6 * progress);
        unbuild.start();
    }

    function play() {
        build.stop();
        unbuild.stop();
        progress = 0;
        pending = true;
        // start on the next frame, once the hidden panel and its squares are drawn at 0
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
        from: 0
        to: 1
        duration: root.duration
        // even speed from the first square to the last (a fast-start curve made it look like it
        // began halfway)
        easing.type: Easing.InOutSine
    }

    NumberAnimation {
        id: unbuild
        target: root
        property: "progress"
        to: 0
        easing.type: Easing.InOutSine
    }

    Item {
        id: holder
        anchors.fill: parent
        layer.enabled: root.progress < 1
        layer.textureSize: Qt.size(Math.ceil(width * Theme.uiScale), Math.ceil(height * Theme.uiScale))
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.0
        }
    }

    Item {
        id: mask
        width: root.width
        height: root.height
        visible: false
        layer.enabled: root.progress < 1

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
