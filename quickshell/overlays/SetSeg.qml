import QtQuick
import "../common"
import "Ui.js" as Ui

// Segmented choice, as the demo's .seg: outlined chips, the chosen one filled in the accent.
// options: [[value, label], ...]; picked(value) fires on click.
Flow {
    id: seg
    property var options: []
    property var value
    signal picked(var value)

    width: parent ? parent.width : 0
    spacing: 4
    Repeater {
        model: seg.options
        Rectangle {
            required property var modelData
            readonly property bool on: seg.value === modelData[0]
            width: label.implicitWidth + 20
            height: label.implicitHeight + 6
            color: on ? Theme.accent : "transparent"
            border.color: on || area.containsMouse ? Theme.accent : Theme.muted
            Text {
                id: label
                anchors.centerIn: parent
                text: parent.modelData[1]
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: parent.on ? Theme.bg : Theme.fg
            }
            MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: seg.picked(parent.modelData[0]) }
        }
    }
}
