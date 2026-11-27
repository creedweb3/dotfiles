import QtQuick
import "../common"

// How panels open and close (Settings > Panels > open motion, Prefs.panim):
//   slide  slide down out from under the bar (SlideReveal)
//   pixel  build out of squares from the box that opened it (PixelReveal)
//   both   the two at once: sliding down while building in
// Same controls as the two: play() on open, unplay() on close, `busy` while either runs.
Item {
    id: root

    default property alias content: pix.content
    property real originX: width / 2
    readonly property string mode: Prefs.panim
    readonly property bool busy: slide.busy || pix.busy

    function play() {
        if (mode !== "pixel")
            slide.play();
        else
            slide.progress = 1;
        if (mode !== "slide")
            pix.play();
        else
            pix.progress = 1;
    }
    function unplay() {
        if (mode !== "pixel")
            slide.unplay();
        if (mode !== "slide")
            pix.unplay();
    }

    SlideReveal {
        id: slide
        anchors.fill: parent

        PixelReveal {
            id: pix
            width: root.width
            height: root.height
            originX: root.originX
            // quick and immediate, like the bar: starts the frame it is clicked, fast-start curve.
            // With the slide it runs a little longer, so the squares still show after it lands.
            duration: root.mode === "both" ? 420 : 360
            instant: true
            closeShare: 0.55   // closing about 0.2s: quicker than opening, so it gets out of the way
        }
    }
}
