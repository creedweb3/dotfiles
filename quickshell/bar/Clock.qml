import QtQuick
import Quickshell
import "../common"

// "Thu Nov 12 | 14:05": day in the accent; a moon while focus mode holds pop-ups back,
// and the count of notifications not yet seen. Click opens the notification centre.
Box {
    id: root

    property string screenName: ""    // the bar's screen, where the centre opens

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        text: Qt.formatDate(clock.date, "ddd")
        color: Theme.accent
    }
    Label {
        text: Qt.formatDate(clock.date, "MMM d")
    }
    Label {
        text: "|"
        color: Theme.muted
    }
    Label {
        text: Qt.formatTime(clock.date, "HH:mm")
    }
    Icon {
        visible: Notifs.dnd
        anchors.verticalCenter: parent.verticalCenter
        path: Icons.moon
        size: 13
        color: Theme.dim
    }

    Rectangle {
        visible: Notifs.unread > 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(16, count.implicitWidth + 8)
        height: 16
        color: Theme.accent

        Text {
            id: count
            anchors.centerIn: parent
            text: Notifs.unread > 99 ? "99+" : Notifs.unread
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            color: Theme.bg
        }
    }

    active: Popup.side === "nc"
    onClicked: Popup.toggleSide("nc", 0, screenName)
}
