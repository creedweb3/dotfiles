import QtQuick
import "../common"

// The demo's text box (.tin): outlined, accent outline while typing. `secret` hides the text.
Rectangle {
    id: field
    property alias text: input.text
    property string placeholder
    property bool secret: false
    signal accepted()

    implicitHeight: 26
    color: "transparent"
    border.color: input.activeFocus ? Theme.accent : Theme.muted

    function focusInput() { input.forceActiveFocus() }

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: Theme.fg
        selectByMouse: true
        onAccepted: field.accepted()
        Text {
            visible: !input.text
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            font: input.font
            color: Theme.dim
        }
    }
}
