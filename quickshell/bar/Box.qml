import QtQuick
import "../common"

// One glass box on the bar: panel colour at 84%, 1px line, accent edge on hover.
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

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.boxHeight
    color: Theme.boxFill
    border.width: 1
    border.color: active || hovered ? Theme.accent : Theme.line
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
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }
}
