import QtQuick
import "../common"

// Slide: what this holds slides down out from under the bar, as the bar does when it appears on
// auto-hide, on the same fast-start curve as Hyprland's window moves ("snap" in hyprland.lua).
// It is clipped at its own top edge, so it looks like it comes out from behind the bar.
// Same controls as PixelReveal: play() when the panel opens, unplay() when it closes, `busy`
// while either runs (keep the window shown till then).
Item {
    id: root

    default property alias content: holder.data
    property real originX: width / 2     // unused here; kept so the hosts can swap reveals
    property int openTime: 240
    property int closeTime: 160
    property real progress: 1            // 0 tucked under the bar, 1 fully down

    readonly property bool busy: anim.running

    // carries on from where it is when reversed mid-way (rapid taps), starts from 0 when fresh
    function play() {
        if (!anim.running)
            progress = 0;
        anim.stop();
        anim.duration = Math.max(1, Math.round(openTime * (1 - progress)));
        anim.to = 1;
        anim.start();
    }
    function unplay() {
        anim.stop();
        anim.duration = Math.max(1, Math.round(closeTime * progress));
        anim.to = 0;
        anim.start();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    clip: progress < 1   // only while moving, so a panel shadow is not cut once it has landed

    Item {
        id: holder
        width: root.width
        height: root.height
        y: -root.height * (1 - root.progress)
    }
}
