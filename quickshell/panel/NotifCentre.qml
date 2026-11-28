import QtQuick
import Quickshell
import "../common"

// The notification centre (click the clock), as the demo: the date on the wallpaper, a month
// calendar with week numbers, then focus mode and the notification history, newest first,
// with dismiss on each and "clear all". Opening it marks everything read (Notifs).
Rectangle {
    id: root

    property int monthOffset: 0      // months away from today; the arrows move it

    width: 380
    color: Theme.glass
    border.width: Theme.border
    border.color: Theme.line

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // swallow clicks so they do not reach the scrim behind and close the centre
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: top
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        // ---- date: the wallpaper at full brightness, the date along the bottom, the time top-right
        Rectangle {
            width: parent.width
            height: 132
            color: Theme.bg
            border.width: 1
            border.color: Theme.line
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Theme.wallpaperPath === "" ? "" : Theme.wallpaperPath.startsWith("/") ? "file://" + Theme.wallpaperPath : Theme.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 760
                asynchronous: true
            }

            Text {
                id: bigDay
                x: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: Qt.formatDate(clock.date, "d")
                font.family: Theme.fontFamily
                font.pixelSize: 58
                font.weight: Font.ExtraBold
                font.letterSpacing: -3
                color: "white"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.6)
            }

            Column {
                x: 92
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 13

                Text {
                    text: Qt.formatDate(clock.date, "dddd").toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 3
                    color: "white"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                }
                Text {
                    text: Qt.formatDate(clock.date, "MMMM yyyy")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Qt.rgba(1, 1, 1, 0.72)
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 10
                text: Qt.formatTime(clock.date, "HH:mm")
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
                color: "white"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.6)
            }
        }

        // ---- calendar
        Card {
            width: parent.width

            CalendarMonth {
                width: parent.width
                offset: root.monthOffset
                today: clock.date
                onMove: d => root.monthOffset = d === 0 ? 0 : root.monthOffset + d
            }
        }
    }

    // ---- notifications: fills the rest of the height
    Card {
        id: notes
        title: "notifications"
        x: 14
        y: top.y + top.height + 10
        width: parent.width - 28
        height: parent.height - y - 14

        Item {
            width: parent.width
            height: 20

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "focus <font color=\"" + Theme.dim + "\">· no pop-ups</font>"
                textFormat: Text.StyledText
            }
            Switch2 {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                on: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
        }

        Flickable {
            id: flick
            width: parent.width
            // the card's height less its padding, title (~15 + 10 spacing), focus row and footer (20 + 6 each)
            height: Math.max(40, notes.height - notes.pad * 2 - notes.tabH - (notes.tab ? 2 : 25) - 52)
            contentHeight: history.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Label {
                visible: Notifs.list.length === 0
                width: parent.width
                topPadding: 22
                horizontalAlignment: Text.AlignHCenter
                text: "all caught up"
                color: Theme.dim
            }

            Column {
                id: history
                width: parent.width
                topPadding: 6

                Repeater {
                    model: ScriptModel {
                        values: Notifs.list
                    }

                    HistoryItem {
                        required property var modelData
                        n: modelData
                        width: history.width
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 20

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.list.length + " notification" + (Notifs.list.length === 1 ? "" : "s")
                color: Theme.dim
                font.pixelSize: Theme.smallSize
            }
            Label {
                visible: Notifs.list.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "clear all"
                color: clearMouse.containsMouse ? Theme.accent : Theme.dim
                font.pixelSize: Theme.smallSize

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }
    }
}
