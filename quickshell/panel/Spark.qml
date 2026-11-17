import QtQuick
import "../common"

// Sparkline: the history as a line with a faint fill under it. Its strength follows
// Settings > Graphs (Prefs.gs).
Canvas {
    id: root

    property var values: []
    property real max: 100      // 0 = scale to the largest value
    property color color: Theme.accent
    readonly property real strength: Prefs.gs / 100

    implicitHeight: 44
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values, n = v.length;
        if (n < 2)
            return;
        const top = max > 0 ? max : Math.max(0.001, ...v);
        const x = i => i / (n - 1) * width, y = val => height - 1 - Math.min(1, val / top) * (height - 2);
        ctx.beginPath();
        ctx.moveTo(0, y(v[0]));
        for (let i = 1; i < n; i++)
            ctx.lineTo(x(i), y(v[i]));
        ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, strength);
        ctx.lineWidth = 1.5;
        ctx.stroke();
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.18 * strength);
        ctx.fill();
    }
}
