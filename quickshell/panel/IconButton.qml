import QtQuick
import "../common"

// A bare icon that acts as a button: accent on hover, or while `toggled`.
Item {
    id: root

    property string icon
    property real size: 18
    property bool toggled: false

    signal clicked

    implicitWidth: size + 10
    implicitHeight: size + 10
    opacity: enabled ? 1 : 0.35

    Icon {
        anchors.centerIn: parent
        path: root.icon
        size: root.size
        stroke: 1.8
        color: mouse.containsMouse || root.toggled ? Theme.accent : Theme.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
