import QtQuick
import "../common"

// Sound / Bluetooth / Wi-Fi status. Settings > Bar > show (Prefs.sysic):
//   peek  just the icon until you point at it, then the value slides open (default);
//         closing waits a moment, so sliding the pointer across the boxes does not flicker
//   text  icon and value always       icon  icon only
Box {
    id: root

    property string icon
    property string value
    property bool off: false
    property bool open: false
    readonly property bool showValue: Prefs.sysic === "text" || (Prefs.sysic === "peek" && open)

    spacing: 0

    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 80
        onTriggered: root.open = false
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        path: root.icon
        size: 16
        color: root.hovered ? Theme.accent : root.off ? Theme.dim : Theme.fg
    }

    Item {
        id: slot
        height: Theme.boxHeight
        width: root.showValue ? values.implicitWidth : 0
        opacity: root.showValue ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: root.showValue ? 300 : 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: root.showValue ? 200 : 120 }
        }

        Row {
            id: values
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 7
            spacing: 7

            Label {
                text: "|"
                color: Theme.muted
            }
            Label {
                text: root.value
                color: root.hovered ? Theme.accent : root.off ? Theme.dim : Theme.fg
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Math.ceil(13 * Theme.fontSize * 0.6))
            }
        }
    }
}
