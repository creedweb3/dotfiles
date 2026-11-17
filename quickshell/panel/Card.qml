import QtQuick
import "../common"

// A panel card with a small uppercase title. Its look is Settings > Panels > pop-up panels
// (Prefs.plook), as the demo:
//   plain  no frame        soft  faint fill        lined  1px muted outline (default)
//   tab    faint fill, the title on an accent tab above the card
// `clickable` cards outline in the accent on hover and emit clicked().
Item {
    id: root

    property string title
    property bool clickable: false
    default property alias content: body.data
    property alias spacing: body.spacing

    signal clicked

    readonly property string look: Prefs.plook
    readonly property bool tab: look === "tab" && title !== ""
    readonly property real tabH: tab ? 19 : 0
    readonly property real pad: look === "lined" ? 12 : 14

    implicitHeight: tabH + col.implicitHeight + pad * 2 + (tab ? 2 : 0)

    Rectangle {
        id: frame
        y: root.tabH
        width: parent.width
        height: parent.height - root.tabH
        color: root.look === "soft" ? Theme.alpha(Theme.fg, 0.06) : root.look === "tab" ? Theme.alpha(Theme.fg, 0.05) : "transparent"
        border.width: root.look === "lined" || (root.clickable && mouse.containsMouse) ? 1 : 0
        border.color: root.clickable && mouse.containsMouse ? Theme.accent : Theme.muted

        Behavior on border.color {
            ColorAnimation { duration: 100 }
        }
    }

    // tab look: the title on an accent tag sitting on the card's top edge
    Rectangle {
        visible: root.tab
        width: tabText.implicitWidth + 18
        height: root.tabH
        color: Theme.alpha(Theme.accent, 0.26)

        Label {
            id: tabText
            anchors.centerIn: parent
            text: root.title.toUpperCase()
            font.pixelSize: Theme.smallSize
            font.letterSpacing: 2
        }
    }

    // below the content: controls inside take their own clicks first
    MouseArea {
        id: mouse
        anchors.fill: frame
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Column {
        id: col
        x: root.pad
        y: root.tabH + root.pad + (root.tab ? 2 : 0)
        width: parent.width - root.pad * 2
        spacing: 10

        Label {
            visible: root.title !== "" && !root.tab
            text: root.title.toUpperCase()
            color: Theme.dim
            font.pixelSize: Theme.smallSize
            font.letterSpacing: 2
        }

        Column {
            id: body
            width: parent.width
            spacing: 6
        }
    }
}
