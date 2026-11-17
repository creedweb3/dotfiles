import QtQuick
import "../common"

// The demo's settings button (.qbtn): outlined, accent on hover; `warn` draws it in the warning red.
Rectangle {
    id: btn
    property string text
    property bool warn: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 26
    color: "transparent"
    opacity: enabled ? 1 : 0.4
    border.color: area.containsMouse ? (warn ? Theme.warn : Theme.accent) : Theme.muted
    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: btn.warn ? Theme.warn : area.containsMouse ? Theme.accent : Theme.fg
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
