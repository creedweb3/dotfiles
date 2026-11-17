import QtQuick
import "../common"

// One notification in the centre's timeline: the time on the left of a thin line with an
// accent square (red for critical), then app, title, a line of body, its actions, and ✕.
Item {
    id: root

    required property var n
    readonly property bool crit: Notifs.isCritical(n)

    implicitHeight: col.implicitHeight + 12

    Label {
        x: 0
        y: 1
        width: 38
        horizontalAlignment: Text.AlignRight
        text: Qt.formatTime(new Date(Notifs.timeOf(root.n)), "HH:mm")
        color: Theme.dim
        font.pixelSize: 10
    }

    // the timeline and this item's marker
    Rectangle {
        x: 47
        width: 1
        height: parent.height
        color: Theme.alpha(Theme.muted, 0.9)
    }
    Rectangle {
        x: 44
        y: 5
        width: 7
        height: 7
        color: root.crit ? Theme.crit : Theme.accent
    }

    Column {
        id: col
        x: 58
        width: parent.width - 58
        spacing: 1

        Item {
            width: parent.width
            height: appName.implicitHeight

            Label {
                id: appName
                width: parent.width - 20
                text: (root.n.appName || "notification").toUpperCase()
                color: Theme.dim
                font.pixelSize: 10
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
            Link {
                anchors.right: parent.right
                text: "✕"
                font.pixelSize: Theme.smallSize
                onClicked: Notifs.dismiss(root.n)
            }
        }

        Label {
            width: parent.width
            text: root.n.summary
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }

        Label {
            visible: text !== ""
            width: parent.width
            text: root.n.body.split("\n")[0]
            textFormat: Text.PlainText
            color: Theme.dim
            elide: Text.ElideRight
        }

        Row {
            visible: root.n.actions.length > 0
            topPadding: 4
            spacing: 12

            Repeater {
                model: root.n.actions

                Label {
                    required property var modelData
                    text: modelData.text
                    color: Theme.accent
                    font.underline: actMouse.containsMouse

                    MouseArea {
                        id: actMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.invoke(root.n, modelData)
                    }
                }
            }
        }
    }
}
