import QtQuick
import "../common"

// The demo's .hsw switch: a 30x16 outline with a sliding square, lit in the accent when on.
Rectangle {
    id: sw
    property bool on: false
    signal toggled()

    implicitWidth: 30
    implicitHeight: 16
    color: "transparent"
    border.color: on ? Theme.accent : Theme.muted
    opacity: enabled ? 1 : 0.4
    Behavior on border.color { ColorAnimation { duration: 200 } }

    Rectangle {
        x: sw.on ? 16 : 2
        y: 2
        width: 10
        height: 10
        color: sw.on ? Theme.accent : Theme.dim
        Behavior on x { NumberAnimation { duration: 200 } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
