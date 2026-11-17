import QtQuick
import "../common"

// A month as the demo's centre shows it: "‹ November 2026 ›" (plus "today" when moved away),
// weekday initials, then weeks starting Monday with their ISO week number. Today is solid
// accent; weekends are dim. move(d): -1 / +1 a month, 0 back to today.
Column {
    id: root

    property int offset: 0
    property date today: new Date()
    readonly property date view: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int first: (view.getDay() + 6) % 7          // Monday = 0
    readonly property int days: new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate()
    readonly property var cells: {
        const c = Array(first).fill(0);
        for (let i = 1; i <= days; i++)
            c.push(i);
        while (c.length % 7)
            c.push(0);
        return c;
    }
    readonly property real cellW: (width - 30) / 7

    signal move(int d)

    spacing: 4

    // ISO 8601 week number of a date
    function weekOf(y, m, d) {
        const t = new Date(Date.UTC(y, m, d));
        const dn = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dn);
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 864e5 + 1) / 7);
    }

    Item {
        width: parent.width
        height: 20

        Link {
            anchors.left: parent.left
            text: "‹"
            onClicked: root.move(-1)
        }
        Row {
            anchors.centerIn: parent
            spacing: 10

            Label {
                text: Qt.formatDate(root.view, "MMMM yyyy")
                font.bold: true
            }
            Link {
                visible: root.offset !== 0
                text: "today"
                onClicked: root.move(0)
            }
        }
        Link {
            anchors.right: parent.right
            text: "›"
            onClicked: root.move(1)
        }
    }

    Row {
        x: 30
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            Label {
                required property string modelData
                width: root.cellW
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.dim
                font.pixelSize: Theme.smallSize
            }
        }
    }

    Repeater {
        model: root.cells.length / 7

        Row {
            id: week
            required property int index
            readonly property var row: root.cells.slice(index * 7, index * 7 + 7)

            Label {
                width: 30
                height: 20
                text: "W" + root.weekOf(root.view.getFullYear(), root.view.getMonth(), week.row.find(x => x > 0))
                color: Theme.dim
                font.pixelSize: 10
            }

            Repeater {
                model: week.row

                Rectangle {
                    required property int modelData
                    required property int index
                    readonly property bool isToday: root.offset === 0 && modelData === root.today.getDate()
                    width: root.cellW
                    height: 20
                    color: isToday ? Theme.accent : "transparent"

                    Label {
                        anchors.centerIn: parent
                        visible: parent.modelData > 0
                        text: parent.modelData
                        color: parent.isToday ? Theme.bg : parent.index > 4 ? Theme.dim : Theme.fg
                        font.pixelSize: Theme.smallSize
                    }
                }
            }
        }
    }
}
