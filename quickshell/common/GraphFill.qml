import QtQuick

// The filled part of a graph (eq bars, meters, the OSD level), in the style chosen in
// Settings > Graphs, as the demo's gs-* classes:
//   flat  one colour          tone  accent2 into accent       fade  from nothing into accent
//   led   4px segments, 2px gaps                              cap   faint body, 4px bright end
// `vertical`: grows upwards (eq bars), else to the right. Strength = Prefs.gs (opacity).
Item {
    id: root

    property bool vertical: false
    property color color: Theme.accent
    property color color2: Theme.accent2
    readonly property real strength: Prefs.gs / 100
    readonly property color ga: Theme.alpha(color, color.a * strength)
    readonly property color ga2: Theme.alpha(color2, color2.a * strength)
    readonly property real length: vertical ? height : width
    clip: true

    // flat, tone, fade: one rectangle with a gradient
    Rectangle {
        anchors.fill: parent
        visible: Prefs.gstyle === "flat" || Prefs.gstyle === "tone" || Prefs.gstyle === "fade"
        color: root.ga
        gradient: Prefs.gstyle === "flat" ? null : grad
    }
    Gradient {
        id: grad
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        // position 0 is the top (vertical) or the left: the far end of a bar growing up, the
        // start of a bar growing right
        GradientStop {
            position: 0
            color: Prefs.gstyle === "tone" ? root.ga2 : root.vertical ? root.ga : "transparent"
        }
        GradientStop {
            position: 1
            color: Prefs.gstyle === "tone" ? root.ga : root.vertical ? "transparent" : root.ga
        }
    }

    // led: segments from the start of the bar
    Repeater {
        model: Prefs.gstyle === "led" ? Math.ceil(root.length / 6) : 0
        Rectangle {
            required property int index
            color: root.ga
            x: root.vertical ? 0 : index * 6
            y: root.vertical ? root.height - index * 6 - 4 : 0
            width: root.vertical ? root.width : 4
            height: root.vertical ? 4 : root.height
        }
    }

    // cap: 40% accent body, the last 4px in full strength
    Rectangle {
        anchors.fill: parent
        visible: Prefs.gstyle === "cap"
        color: Theme.alpha(root.color, 0.4)
    }
    Rectangle {
        visible: Prefs.gstyle === "cap"
        color: root.ga
        x: root.vertical ? 0 : Math.max(0, root.width - 4)
        y: 0
        width: root.vertical ? root.width : Math.min(4, root.width)
        height: root.vertical ? Math.min(4, root.height) : root.height
    }
}
