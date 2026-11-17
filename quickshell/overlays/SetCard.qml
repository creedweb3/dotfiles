import QtQuick
import "../common"
import "Ui.js" as Ui

// A settings card, in the look picked in Settings > Panels > settings window (Prefs.slook):
//   plain  no outline, no fill        soft  faint fill
//   lined  thin outline, faint fill   tab   faint fill, the title on a tab above the card
// `action` adds a link at the right of the title (e.g. "check now"); clicking it emits actionClicked().
Item {
    id: card
    property string title
    property string action
    signal actionClicked()
    default property alias content: inner.data

    readonly property string look: Prefs.slook
    readonly property bool tab: look === "tab" && !!title
    width: parent ? parent.width : 0
    implicitHeight: box.y + box.height

    Rectangle {  // the tab: title on an accent-tinted strip above the card
        visible: card.tab
        height: 19
        width: tabText.implicitWidth + 18
        color: Ui.alpha(Theme.accent, 0.26)
        Text {
            id: tabText
            anchors.centerIn: parent
            text: card.title.toUpperCase()
            font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 2 }
            color: Theme.fg
        }
    }

    Rectangle {
        id: box
        y: card.tab ? 19 : 0
        width: parent.width
        height: col.implicitHeight + 28
        color: card.look === "plain" ? "transparent" : Ui.alpha(Theme.fg, card.look === "soft" ? 0.06 : card.look === "tab" ? 0.05 : 0.03)
        border.color: card.look === "lined" ? Theme.muted : "transparent"

        Column {
            id: col
            x: 14; y: 14
            width: parent.width - 28
            spacing: 6
            Item {
                width: parent.width
                height: head.implicitHeight
                visible: (!!card.title && !card.tab) || !!card.action
                Text {
                    id: head
                    visible: !card.tab
                    text: card.title.toUpperCase()
                    font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 2 }
                    color: Theme.dim
                }
                Text {
                    visible: !!card.action
                    anchors.right: parent.right
                    text: card.action + " ›"
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    color: linkArea.containsMouse ? Theme.fg : Theme.accent
                    MouseArea { id: linkArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.actionClicked() }
                }
            }
            Column {
                id: inner
                width: parent.width
                spacing: 8
            }
        }
    }
}
