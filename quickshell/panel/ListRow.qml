import QtQuick
import "../common"

// A pickable row as the demo's lists: name on the left, a dim detail on the right, an accent
// outline on the current one, a faint accent wash under the pointer.
Rectangle {
    id: root

    property string name
    property string detail
    property bool on: false

    signal clicked

    implicitHeight: 32
    color: mouse.containsMouse ? Theme.alpha(Theme.accent, 0.1) : "transparent"
    border.width: 1
    border.color: on ? Theme.accent : "transparent"

    Label {
        x: 10
        width: parent.width - detailLabel.implicitWidth - 30
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        elide: Text.ElideRight
    }
    Label {
        id: detailLabel
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.detail
        color: Theme.dim
        font.pixelSize: Theme.smallSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
