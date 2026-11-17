import QtQuick
import "../common"

// Dim text that turns accent under the pointer and emits clicked().
Label {
    id: root

    signal clicked

    color: mouse.containsMouse ? Theme.accent : Theme.dim

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
