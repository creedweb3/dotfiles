import QtQuick
import Quickshell
import "../common"
import "../panel"

// One notification pop-up: icon, "app · now" with a close cross, title, two lines of body,
// action buttons, and the time-left line (paused while pointed at; none for critical ones).
Rectangle {
    id: root

    required property var n
    property bool tinted: true
    readonly property bool crit: Notifs.isCritical(n)
    readonly property int life: n.expireTimeout > 0 ? n.expireTimeout * 1000 : 5000
    readonly property string pic: Notifs.iconOf(n)
    // a track-change notification from the music app: its cover as a small record in the media
    // player's style (Settings > Panels > media player), turning while the music plays
    readonly property bool music: {
        const p = Sys.player;
        if (!p || pic === "" || Prefs.mstyle === "poster")
            return false;
        const app = (n.appName || "").toLowerCase(), id = (p.identity || "").toLowerCase(), de = (p.desktopEntry || "").toLowerCase();
        return app !== "" && (app === id || app === de || id.indexOf(app) >= 0 || app.indexOf(id) >= 0 || (de !== "" && app.indexOf(de) >= 0));
    }
    property real remain: 1           // share of the time left, 1 -> 0

    signal openCentre

    implicitHeight: body.implicitHeight + 22
    // a slightly lighter surface than the windows: the theme's text colour mixed in;
    // tinted also mixes the accent in (critical ones stay neutral so their red stands out)
    color: Theme.alpha(tinted && !crit ? Theme.mix(Theme.accent, Theme.mix(Theme.fg, Theme.bg, 0.06), 0.09) : Theme.mix(Theme.fg, Theme.bg, 0.07), 0.94)
    border.width: 1
    border.color: crit ? Theme.crit : Theme.line
    clip: true

    // slide in from the left
    opacity: 0
    transform: Translate { id: shift; x: -24 }
    Component.onCompleted: appear.start()
    ParallelAnimation {
        id: appear
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 200 }
        NumberAnimation { target: shift; property: "x"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }

    HoverHandler {
        id: hover
    }

    // click anywhere else on the toast: hide it and open the centre
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Notifs.hideToast(root.n);
            root.openCentre();
        }
    }

    Row {
        id: body
        x: 12
        y: 10
        width: parent.width - 24
        spacing: 10

        DiscFace {
            visible: root.music
            width: 44
            height: 44
            source: root.music ? root.pic : ""
            vinyl: Prefs.mstyle === "vinyl"
            spinning: root.music && Sys.player !== null && Sys.player.isPlaying
        }

        Rectangle {
            visible: !root.music
            width: 32
            height: 32
            color: "transparent"
            border.width: 1
            border.color: root.crit ? Theme.crit : Theme.muted

            Image {
                id: pic
                visible: status === Image.Ready
                anchors.centerIn: parent
                width: 20
                height: 20
                sourceSize: Qt.size(40, 40)
                fillMode: Image.PreserveAspectFit
                source: root.pic !== "" ? root.pic : root.n.appName === "rice" ? Theme.symbolPath : ""
                asynchronous: true
            }
            Icon {
                visible: pic.status !== Image.Ready
                anchors.centerIn: parent
                size: 18
                path: "M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0"
                color: root.crit ? Theme.crit : Theme.accent
            }
        }

        Column {
            width: parent.width - (root.music ? 54 : 42)
            spacing: 2

            Item {
                width: parent.width
                height: head.implicitHeight

                Label {
                    id: head
                    width: parent.width - 20
                    text: (root.n.appName || "notification") + " · now"
                    color: Theme.dim
                    font.pixelSize: Theme.smallSize
                    elide: Text.ElideRight
                }
                Icon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    path: Icons.cross
                    size: 11
                    stroke: 2.4
                    color: closeMouse.containsMouse ? Theme.accent : Theme.dim

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.hideToast(root.n)
                    }
                }
            }

            Label {
                width: parent.width
                text: root.n.summary
                textFormat: Text.PlainText
                font.bold: true
                elide: Text.ElideRight
            }

            Label {
                visible: text !== ""
                width: parent.width
                text: root.n.body
                textFormat: Text.PlainText
                color: Theme.dim
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // action buttons wrap onto a new line, and a long label ends in "…"
            Flow {
                visible: root.n.actions.length > 0
                width: parent.width
                topPadding: 6
                spacing: 6

                Repeater {
                    model: root.n.actions

                    Rectangle {
                        required property var modelData
                        width: Math.min(actLabel.implicitWidth + 20, parent.width)
                        height: 22
                        color: "transparent"
                        border.width: 1
                        border.color: actMouse.containsMouse ? Theme.accent : Theme.muted

                        Label {
                            id: actLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 16)
                            elide: Text.ElideRight
                            text: modelData.text
                            color: actMouse.containsMouse ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.smallSize
                        }
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

    // time left; pointing at the toast pauses it, and so the timer
    Rectangle {
        id: timeLine
        visible: !root.crit
        anchors.bottom: parent.bottom
        height: 2
        width: parent.width * root.remain
        color: Theme.accent
    }

    NumberAnimation on remain {
        running: !root.crit
        paused: running && hover.hovered
        from: 1
        to: 0
        duration: root.life
        onFinished: Notifs.hideToast(root.n)
    }
}
