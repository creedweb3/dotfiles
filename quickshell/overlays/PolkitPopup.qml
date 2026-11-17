import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import "../common"
import "Ui.js" as Ui

// Admin password (the polkit agent): a card over a dimmed screen when an app asks for admin rights.
// Enter or › allows, esc or ‹ cancel closes, a wrong password shakes the card and turns it red.
// Only one polkit agent can run: don't start polkit-gnome (or another agent) next to this.
// Look (Settings > Panels > admin password, Prefs.pk), as the demo:
//   card     framed card                 corners  no frame, accent corners floating off the card
//   strip    a strip of the wallpaper with the symbol, the form beside it
Scope {
    id: root

    readonly property var flow: agent.flow
    property bool bad: false
    property bool showDetails: false
    property string error: ""

    function submit() {
        if (!flow || !input.text) return
        flow.submit(input.text)
        input.text = ""
    }
    function cancel() { if (flow) flow.cancelAuthenticationRequest() }

    PolkitAgent {
        id: agent
        onIsActiveChanged: {
            if (isActive) {
                root.bad = false
                root.error = ""
                root.showDetails = false
                input.text = ""
                win.show()
                Qt.callLater(() => input.forceActiveFocus())
            } else {
                win.open = false
            }
        }
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.bad = true
            root.error = root.flow.supplementaryIsError && root.flow.supplementaryMessage
                ? root.flow.supplementaryMessage : "wrong password · try again"
            shake.restart()
        }
        function onSupplementaryMessageChanged() {
            if (root.flow.supplementaryIsError && root.flow.supplementaryMessage) root.error = root.flow.supplementaryMessage
        }
    }

    OverlayWindow {
        id: win
        name: "polkit"
        dim: 0.38
        onDismissed: root.cancel()

        Rectangle {
            id: card
            readonly property color tone: root.bad ? Theme.crit : Theme.accent
            readonly property bool corners: Prefs.pk === "corners"
            readonly property bool strip: Prefs.pk === "strip"
            readonly property int artW: strip ? 150 : 0
            property real shift: 0
            x: Math.round((parent.width - width) / 2 + shift)
            y: Math.round((parent.height - height) / 2)
            width: strip ? 540 : 420
            height: body.implicitHeight + (strip ? 40 : corners ? 56 : 52)
            color: Ui.alpha(Theme.bg, corners ? 0.86 : 0.92)
            border.color: corners ? "transparent" : Theme.muted
            MouseArea { anchors.fill: parent }

            // corners: 18px brackets, 8px off the card
            Repeater {
                model: card.corners ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []
                Item {
                    required property var modelData
                    x: modelData[0] ? card.width - 10 : -8
                    y: modelData[1] ? card.height - 10 : -8
                    width: 18
                    height: 18
                    Rectangle { width: 18; height: 2; y: parent.modelData[1] ? 16 : 0; color: card.tone }
                    Rectangle { width: 2; height: 18; x: parent.modelData[0] ? 16 : 0; color: card.tone }
                }
            }

            // strip: the wallpaper, fading into the card at the bottom, with the symbol
            Item {
                visible: card.strip
                x: 1; y: 1
                width: card.artW - 1
                height: card.height - 2
                clip: true
                Image {
                    anchors.fill: parent
                    source: Theme.wallpaperPath ? "file://" + Theme.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1.0; color: Ui.alpha(Theme.bg, 0.85) }
                    }
                }
                Symbol { size: 34; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 } }
            }
            Rectangle { visible: card.strip; x: card.artW; y: 1; width: 2; height: card.height - 2; color: card.tone }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: card; property: "shift"; to: -7; duration: 80 }
                NumberAnimation { target: card; property: "shift"; to: 7; duration: 160 }
                NumberAnimation { target: card; property: "shift"; to: 0; duration: 80 }
            }

            ColumnLayout {
                id: body
                readonly property int align: card.strip ? Qt.AlignLeft : Qt.AlignHCenter
                x: card.strip ? card.artW + 24 : card.corners ? 30 : 28
                y: card.strip ? 22 : card.corners ? 28 : 26
                width: card.width - x - (card.strip ? 22 : card.corners ? 30 : 28)
                spacing: card.strip ? 12 : 14

                Symbol { visible: !card.strip; size: 40; Layout.alignment: Qt.AlignHCenter }
                Text {
                    Layout.alignment: body.align
                    text: "ADMIN PASSWORD"
                    font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 3 }
                    color: Ui.mix(Theme.fg, Theme.bg, 0.7)
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: card.strip ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.message : ""
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    color: Ui.mix(Theme.fg, Theme.bg, 0.85)
                }
                Text {  // who is asked: the identity polkit will check
                    Layout.alignment: body.align
                    text: "  " + (root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName : "")
                    font { family: Theme.fontFamily; pixelSize: 12 }
                    color: Theme.dim
                }

                Rectangle {  // password field
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: Ui.alpha(Theme.bg, 0.55)
                    border.color: card.tone
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 12; rightMargin: 36 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        font { family: Theme.fontFamily; pixelSize: 13; letterSpacing: 4 }
                        color: card.tone
                        selectionColor: Ui.alpha(card.tone, 0.4)
                        cursorDelegate: Rectangle { width: 2; color: card.tone }
                        onTextChanged: if (text) { root.bad = false; root.error = "" }
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) root.cancel()
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.submit()
                            else return
                            e.accepted = true
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "›"
                        font { pixelSize: 22; weight: Font.Light }
                        color: card.tone
                        MouseArea { anchors { fill: parent; margins: -6 } onClicked: root.submit() }
                    }
                }
                Text {
                    visible: !!root.error
                    Layout.fillWidth: true
                    Layout.topMargin: -6
                    wrapMode: Text.Wrap
                    text: root.error
                    font { family: Theme.fontFamily; pixelSize: 12 }
                    color: Theme.crit
                }
                Text {
                    visible: root.showDetails
                    Layout.fillWidth: true
                    Layout.topMargin: -6
                    wrapMode: Text.WrapAnywhere
                    text: root.flow ? "action " + root.flow.actionId : ""
                    font { family: Theme.fontFamily; pixelSize: 12 }
                    color: Theme.dim
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "‹ cancel"
                        font { family: Theme.fontFamily; pixelSize: 12 }
                        color: cancelArea.containsMouse ? Theme.fg : Ui.mix(Theme.fg, Theme.bg, 0.6)
                        MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.cancel() }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.showDetails ? "details ‹" : "details ›"
                        font { family: Theme.fontFamily; pixelSize: 12 }
                        color: detArea.containsMouse ? Theme.fg : Ui.mix(Theme.fg, Theme.bg, 0.6)
                        MouseArea { id: detArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.showDetails = !root.showDetails }
                    }
                }
            }
        }
    }
}
