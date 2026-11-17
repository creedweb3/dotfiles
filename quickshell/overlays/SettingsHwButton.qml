import QtQuick
import "../common"

// Outlined accent button used by the hardware settings pages (filled on hover, like "update now").
Rectangle {
    id: btn
    property string text
    property bool filled: false
    signal clicked()

    width: label.implicitWidth + 20
    height: 26
    color: filled || area.containsMouse ? Theme.accent : "transparent"
    border.color: Theme.accent
    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: btn.filled || area.containsMouse ? Theme.bg : Theme.accent
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
}
