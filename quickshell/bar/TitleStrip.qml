import QtQuick
import "../common"

// One copy of the music box's scrolling title: the title twice, a gap apart, at scroll position
// `sx` (Music.qml draws a sharp copy in the middle and faded copies at the two ends).
// The final on-screen position is snapped to whole device pixels: natively rendered glyphs drawn
// at fractional positions get re-rasterised every frame and shimmer while scrolling.
Row {
    id: strip
    property string text
    property bool loop: false
    property real gap: 0
    // the scrolling box and the scroll position within it. Every copy rounds the same on-screen
    // position, so the sharp middle and each fade column always agree to the pixel (rounding each
    // copy separately left neighbouring columns a pixel apart, which tore the letters).
    property Item frame
    property real sx: 0

    x: {
        const s = Theme.uiScale
        const fx = frame ? frame.mapToItem(null, 0, 0).x : 0
        const ox = parent ? parent.mapToItem(null, 0, 0).x : 0
        return Math.round((fx + sx) * s) / s - ox
    }
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    spacing: Theme.snap(gap)

    Label {
        text: strip.text
        color: Theme.fg
    }
    Label {
        visible: strip.loop
        text: strip.text
        color: Theme.fg
    }
}
