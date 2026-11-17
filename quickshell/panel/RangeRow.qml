import QtQuick
import "../common"

// "volume  ────■──────  64%": dim label, slider, value.
Row {
    id: root

    property string label
    property real value: 0
    property string valueText: Math.round(value) + "%"

    signal moved(real v)

    spacing: 12
    height: 22

    Label {
        width: 96
        height: parent.height
        text: root.label
        color: Theme.dim
        elide: Text.ElideRight
    }

    Slider {
        width: root.width - 96 - 44 - root.spacing * 2
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        onMoved: v => root.moved(v)
    }

    Label {
        width: 44
        height: parent.height
        horizontalAlignment: Text.AlignRight
        text: root.valueText
    }
}
