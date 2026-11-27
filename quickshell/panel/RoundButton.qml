import QtQuick
import "../common"

// A round outlined button (the media tab's disc layout); `big` is the play button.
Rectangle {
    id: rb
    property string icon
    property bool big: false
    signal clicked()
    width: big ? 52 : 40
    height: width
    radius: width / 2
    color: rbMouse.containsMouse && enabled ? Theme.alpha(Theme.accent, 0.15) : "transparent"
    border.width: 1
    border.color: rbMouse.containsMouse && enabled ? Theme.accent : Theme.muted
    opacity: enabled ? 1 : 0.4
    Icon {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: rb.icon === Icons.play ? 2 : 0
        path: rb.icon
        size: rb.big ? 20 : 15
        color: rb.big ? Theme.fg : Theme.dim
    }
    MouseArea {
        id: rbMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rb.clicked()
    }
}
