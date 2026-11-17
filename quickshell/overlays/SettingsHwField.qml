import QtQuick
import "../common"

// Small outlined text field (times like 21:30). edited(text) fires when editing finishes.
Rectangle {
    id: field
    property alias text: input.text
    property int maxLength: 5
    signal edited(string text)

    width: 90
    height: 26
    color: "transparent"
    border.color: input.activeFocus ? Theme.accent : Theme.muted
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter
        maximumLength: field.maxLength
        selectByMouse: true
        clip: true
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.bg
        onEditingFinished: field.edited(text)
    }
}
