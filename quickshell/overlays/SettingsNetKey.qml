import QtQuick
import QtQuick.Layouts
import "../common"
import "Ui.js" as Ui

// One line of the demo's .keys list: the name in dim text, the value in the accent, a faint rule below.
Item {
    id: keyRow
    property string key
    property string value
    width: parent ? parent.width : 0
    implicitHeight: 24
    RowLayout {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        Text { text: keyRow.key; font { family: Theme.fontFamily; pixelSize: 13 } color: Theme.dim }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: keyRow.value
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.accent
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Ui.alpha(Theme.muted, 0.5) }
}
