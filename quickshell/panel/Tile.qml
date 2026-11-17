import QtQuick
import "../common"

// Quick toggle: icon, name, state underneath. On: accent outline and a light accent wash.
Rectangle {
    id: root

    property string icon
    property string label
    property string sub
    property bool on: false

    signal clicked

    implicitHeight: col.implicitHeight + 14
    color: on ? Theme.alpha(Theme.accent, 0.16) : "transparent"
    border.width: 1
    border.color: on || mouse.containsMouse ? Theme.accent : Theme.muted

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Column {
        id: col
        x: 8
        y: 7
        width: parent.width - 16
        spacing: 4

        Icon {
            path: root.icon
            size: 18
            stroke: 1.7
            color: root.on ? Theme.accent : Theme.fg
        }
        Label {
            text: root.label
            font.weight: Font.DemiBold
            width: parent.width
            elide: Text.ElideRight
        }
        Label {
            text: root.sub
            color: Theme.dim
            font.pixelSize: Theme.smallSize
            width: parent.width
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
