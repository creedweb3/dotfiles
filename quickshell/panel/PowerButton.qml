import QtQuick
import Quickshell
import "../common"

// Power action. `hold` > 0: press and hold that many milliseconds to confirm. While held, water
// rises across the button from the left (the demo's sweep: a tilted, rolling sine edge, with a
// lighter crest running just ahead); releasing early drains it back. hold = 0 fires on click.
Rectangle {
    id: root

    property string icon
    property string label
    property var command: []
    property int hold: 0
    property real progress: 0
    property real phase: 0

    implicitHeight: 52
    color: "transparent"
    border.width: 1
    border.color: mouse.containsMouse || mouse.pressed ? Theme.accent : Theme.muted
    clip: true

    function fire() {
        Popup.close();
        Quickshell.execDetached(command);
    }

    // the water: p = progress 0-1, ph = wave phase (keeps rolling while held)
    Canvas {
        id: water
        anchors.fill: parent
        visible: root.progress > 0

        function sweep(ctx, p, ph) {
            const W = width, H = height, A = H * 0.12, L = H * 0.9, tilt = 0.35;
            const x0 = -A - tilt * H * 0.55 + p * (W + 2 * A + tilt * H * 1.1);
            ctx.beginPath();
            ctx.moveTo(-50, -0.1 * H);
            ctx.lineTo(-50, 1.1 * H);
            for (let i = 16; i >= 0; i--) {
                const y = -0.05 * H + i * (1.1 * H / 16);
                ctx.lineTo(x0 - tilt * (y - H / 2) + A * Math.sin(y / L * 2 * Math.PI + ph), y);
            }
            ctx.closePath();
            ctx.fill();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.progress <= 0)
                return;
            ctx.fillStyle = Theme.alpha(Theme.accent, 0.34);
            sweep(ctx, Math.min(1, root.progress + 0.05), root.phase + 1.6);
            ctx.fillStyle = Theme.alpha(Theme.accent, 0.62);
            sweep(ctx, root.progress, root.phase);
        }
    }

    // keeps the wave rolling while there is water
    Timer {
        running: root.progress > 0
        interval: 16
        repeat: true
        onTriggered: {
            root.phase = Date.now() / 220;
            water.requestPaint();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            path: root.icon
            size: 18
            stroke: 1.7
            color: mouse.containsMouse || mouse.pressed ? Theme.fg : Theme.dim
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: holdAnim.running ? "keep holding" : root.label
            font.pixelSize: Theme.smallSize
            color: mouse.containsMouse || mouse.pressed ? Theme.fg : Theme.dim
        }
    }

    NumberAnimation {
        id: holdAnim
        target: root
        property: "progress"
        to: 1
        onFinished: if (root.progress >= 1) {
            root.progress = 0;
            root.fire();
        }
    }
    NumberAnimation {
        id: drain
        target: root
        property: "progress"
        to: 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (root.hold > 0) {
                drain.stop();
                holdAnim.duration = root.hold * (1 - root.progress);
                holdAnim.restart();
            }
        }
        onClicked: if (root.hold === 0) root.fire()
        onReleased: {
            if (!holdAnim.running)
                return;
            holdAnim.stop();
            drain.duration = 250 * root.progress;
            drain.restart();
        }
    }
}
