import QtQuick
import QtQuick.Layouts
import "../common"

// A labelled settings row: the label in a fixed 132px column, the control filling the rest.
// With `pref` set to a Prefs key, a small mark at the right shows whether the value is the default:
//   ✓  it is the default
//   ↺  back to the default          ☆  make this value the default (asks: set default ✓ ✕)
RowLayout {
    id: row
    property string label
    property string pref: ""
    property bool asking: false
    default property alias control: holder.data
    readonly property bool isDef: pref === "" || Prefs.isDefault(pref)
    width: parent ? parent.width : 0
    spacing: 12
    onIsDefChanged: if (isDef) asking = false

    component Mark: Text {
        id: mark
        property string tip
        signal clicked()
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: markArea.containsMouse ? Theme.fg : Theme.accent
        MouseArea { id: markArea; anchors { fill: parent; margins: -3 } hoverEnabled: true; onClicked: mark.clicked() }
    }

    Text {
        Layout.preferredWidth: 132
        text: row.label
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 13 }
        color: Theme.dim
    }
    Item {
        id: holder
        Layout.fillWidth: true
        implicitHeight: childrenRect.height
    }
    Row {
        visible: row.pref !== ""
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
        Text {
            visible: row.isDef
            text: "✓"
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.muted
        }
        Mark { visible: !row.isDef && !row.asking; text: "↺"; onClicked: Prefs.reset(row.pref) }
        Mark { visible: !row.isDef && !row.asking; text: "☆"; onClicked: row.asking = true }
        Text {
            visible: row.asking
            text: "set default"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
        Mark { visible: row.asking; text: "✓"; onClicked: { Prefs.makeDefault(row.pref); row.asking = false } }
        Mark { visible: row.asking; text: "✕"; onClicked: row.asking = false }
    }
}
