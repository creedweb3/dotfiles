import QtQuick
import "../common"

// The demo's small square switch: 34 x 18 frame, a 12px knob that slides right and turns
// accent when on. Emits toggled(); the owner flips `on`.
Rectangle {
    id: root

    property bool on: false

    signal toggled

    width: 34
    height: 18
    color: "transparent"
    border.width: 1
    border.color: on ? Theme.accent : Theme.muted

    Rectangle {
        x: root.on ? 18 : 2
        y: 2
        width: 12
        height: 12
        color: root.on ? Theme.accent : Theme.dim

        Behavior on x {
            NumberAnimation { duration: 150 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
