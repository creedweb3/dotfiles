import QtQuick
import "../common"

// The quick panel (SUPER+C, or click the bar's centre): tabs Dashboard, Media, System, Deck, Theme.
// The panel keeps the tallest height it has shown, so switching tabs does not make it jump.
Rectangle {
    id: root

    readonly property var tabs: [["dash", "Dashboard"], ["media", "Media"], ["system", "System"], ["deck", "Deck"], ["theme", "Theme"]]
    property real tallest: 0

    width: 500
    height: Math.max(tallest, col.implicitHeight + 28)
    color: Theme.glass
    border.width: 1
    border.color: Theme.line

    // swallow clicks so they do not reach the scrim behind and close the panel
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        onImplicitHeightChanged: root.tallest = Math.max(root.tallest, implicitHeight + 28)

        Row {
            width: parent.width
            spacing: 4

            Repeater {
                model: root.tabs

                Rectangle {
                    required property var modelData
                    readonly property bool on: Popup.tab === modelData[0]
                    width: (parent.width - 4 * (root.tabs.length - 1)) / root.tabs.length
                    height: 32
                    color: on ? Theme.accent : "transparent"
                    border.width: 1
                    border.color: on ? Theme.accent : Theme.muted

                    Label {
                        anchors.centerIn: parent
                        text: modelData[1]
                        color: parent.on ? Theme.bg : tabMouse.containsMouse ? Theme.fg : Theme.dim
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Popup.tab = modelData[0]
                    }
                }
            }
        }

        Loader {
            width: parent.width
            sourceComponent: ({media: media, system: system, deck: deck, theme: theme})[Popup.tab] || dash
        }
    }

    Component {
        id: dash
        Dashboard {}
    }
    Component {
        id: media
        MediaTab {}
    }
    Component {
        id: system
        SystemTab {}
    }
    Component {
        id: deck
        DeckTab {}
    }
    Component {
        id: theme
        ThemeTab {}
    }
}
