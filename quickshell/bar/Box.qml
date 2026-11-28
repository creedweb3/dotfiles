import QtQuick
import "../common"

// One glass box on the bar: panel colour at 84%, outlined like a window (Theme.border / line),
// lit like the focused window on hover.
Rectangle {
    id: root

    default property alias content: row.data
    property bool active: false        // e.g. its pop-up is open
    property bool centered: true
    property int padding: 10
    property alias spacing: row.spacing
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(real dy)

    // whole screen pixels, so the boxes after this one start on a pixel and every border is equal
    implicitWidth: Theme.snapUp(row.implicitWidth + padding * 2)
    implicitHeight: Theme.boxHeight
    color: Theme.boxFill
    border.width: Theme.border
    border.color: active || hovered ? Theme.edge : Theme.line
    clip: true

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: root.centered ? parent.horizontalCenter : undefined
        anchors.left: root.centered ? undefined : parent.left
        anchors.leftMargin: root.padding
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        // react on press: a click needs press and release on the same spot, and boxes that
        // slide open on hover can move between the two, dropping the click
        onPressed: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }
}
