import QtQuick
import "../common"

// Thin slider as the demo's range input: 4px track, accent fill, 10 x 14 square thumb.
// `value` is shown; dragging, clicking or scrolling emits moved(v) and shows the drag
// value until released, so an outside binding to `value` stays intact.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 5
    property real dragValue: 0
    readonly property bool pressed: mouse.pressed
    readonly property real shown: pressed ? dragValue : value
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    signal moved(real v)

    implicitHeight: 16
    implicitWidth: 120

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        color: Theme.alpha(Theme.muted, 0.7)

        Rectangle {
            width: parent.width * root.frac
            height: parent.height
            color: Theme.accent
        }
    }

    Rectangle {
        x: root.frac * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 14
        color: mouse.containsMouse || mouse.pressed ? Theme.fg : Theme.accent

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    function valueAt(x) {
        const f = Math.max(0, Math.min(1, (x - 5) / (width - 10)));
        return from + f * (to - from);
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: m => {
            root.dragValue = root.valueAt(m.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: m => {
            if (!pressed)
                return;
            root.dragValue = root.valueAt(m.x);
            root.moved(root.dragValue);
        }
        onWheel: w => root.moved(Math.max(root.from, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
