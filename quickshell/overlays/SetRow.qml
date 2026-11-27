import QtQuick
import QtQuick.Layouts
import "../common"

// A labelled settings row: the label in a fixed 132px column, the control filling the rest.
// With `pref` set to a Prefs key, a small mark at the right shows whether the value is the default:
//   check  it is the default
//   undo   back to the default      star  make this value the default (asks: set default, check / cross)
// Line icons (Icons.qml), not text symbols: the font has no glyphs for those and squashes them.
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

    component Mark: Item {
        id: mark
        property string icon
        property string tip
        signal clicked()
        implicitWidth: 16
        implicitHeight: 16
        Icon {
            anchors.centerIn: parent
            path: mark.icon
            size: 14
            stroke: 2
            color: markArea.containsMouse ? Theme.fg : Theme.accent
        }
        MouseArea { id: markArea; anchors { fill: parent; margins: -4 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mark.clicked() }
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
        Icon {
            visible: row.isDef
            anchors.verticalCenter: parent.verticalCenter
            path: Icons.check
            size: 14
            stroke: 2
            color: Theme.muted
        }
        Mark { visible: !row.isDef && !row.asking; icon: Icons.undo; onClicked: Prefs.reset(row.pref) }
        Mark { visible: !row.isDef && !row.asking; icon: Icons.star; onClicked: row.asking = true }
        Text {
            visible: row.asking
            anchors.verticalCenter: parent.verticalCenter
            text: "set default"
            font { family: Theme.fontFamily; pixelSize: 11 }
            color: Theme.dim
        }
        Mark { visible: row.asking; icon: Icons.check; onClicked: { Prefs.makeDefault(row.pref); row.asking = false } }
        Mark { visible: row.asking; icon: Icons.cross; onClicked: row.asking = false }
    }
}
