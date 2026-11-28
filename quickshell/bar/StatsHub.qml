import QtQuick
import "../common"

// Centre of the bar: "cpu | (symbol) | mem". Two boxes with round notches face the
// preset's symbol on a disc; hovering spins or swings the symbol (Settings > Bar >
// hover animation), clicking opens the quick panel.
Item {
    id: root

    readonly property real r: 20
    readonly property bool hovered: mouse.containsMouse
    readonly property color edge: hovered || Popup.mode === "panel" ? Theme.accent : Theme.line

    implicitWidth: left.width + right.width
    implicitHeight: Theme.boxHeight

    NotchBox {
        id: left
        notchRight: true
        r: root.r
        edge: root.edge
        width: cpuText.implicitWidth + 10 + root.r + 8
        height: parent.height

        Label {
            id: cpuText
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "cpu " + String(Stats.cpu).padStart(2) + "%"
        }
    }

    NotchBox {
        id: right
        x: left.width
        notchRight: false
        r: root.r
        edge: root.edge
        width: memText.implicitWidth + root.r + 8 + 10
        height: parent.height

        Label {
            id: memText
            x: root.r + 8
            anchors.verticalCenter: parent.verticalCenter
            text: "mem " + String(Stats.mem).padStart(2) + "%"
        }
    }

    // the disc with the symbol, centred on the seam between the two boxes
    Rectangle {
        // as tall as the boxes, which is the bar's full height: any taller and it is clipped
        width: Theme.boxHeight
        height: Theme.boxHeight
        radius: width / 2
        x: left.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(Theme.panel, 0.9)
        border.width: 1
        border.color: root.edge

        Image {
            id: symbol
            anchors.fill: parent
            anchors.margins: 3
            source: Theme.symbolPath
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: false
            rotation: root.hovered && Prefs.anim === "spin" ? 360 : 0

            Behavior on rotation {
                enabled: Prefs.anim === "spin"
                NumberAnimation { duration: 580; easing.type: Easing.OutBack }
            }

            // demo "swing": 20°, -15°, 9°, -4°, rest, over 0.6s. A separate transform, so the
            // spin binding on `rotation` stays intact.
            transform: Rotation {
                id: swingRot
                origin.x: symbol.width / 2
                origin.y: symbol.height / 2
            }
            SequentialAnimation {
                id: swing
                NumberAnimation { target: swingRot; property: "angle"; to: 20; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: swingRot; property: "angle"; to: -15; duration: 120; easing.type: Easing.InOutQuad }
                NumberAnimation { target: swingRot; property: "angle"; to: 9; duration: 120; easing.type: Easing.InOutQuad }
                NumberAnimation { target: swingRot; property: "angle"; to: -4; duration: 120; easing.type: Easing.InOutQuad }
                NumberAnimation { target: swingRot; property: "angle"; to: 0; duration: 120; easing.type: Easing.OutQuad }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: Popup.toggle("panel")
        onEntered: if (Prefs.anim === "swing") swing.restart()
    }
}
