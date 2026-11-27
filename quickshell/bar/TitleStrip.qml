import QtQuick
import "../common"

// One copy of the music box's scrolling title: the title twice, a gap apart, at scroll position
// `sx` (Music.qml draws a sharp copy in the middle and faded copies at the two ends).
Row {
    property string text
    property bool loop: false
    property real gap: 0
    property real sx: 0

    x: sx
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    spacing: gap

    Label {
        text: parent.text
        color: Theme.fg
    }
    Label {
        visible: parent.loop
        text: parent.text
        color: Theme.fg
    }
}
