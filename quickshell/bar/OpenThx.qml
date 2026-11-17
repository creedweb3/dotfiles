import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// openTHX: the playing app's sound mode, from `openthx-ctl bar` (JSON: text, tooltip, class).
// Click cycles the mode, right click picks any app's mode, middle click turns spatial on/off.
// Hidden when openthx-ctl is not installed.
Box {
    id: root

    readonly property string ctl: Theme.home + "/.local/bin/openthx-ctl"
    property string text: ""

    visible: text !== ""

    Label {
        text: root.text
    }

    Process {
        id: poll
        command: [root.ctl, "bar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.text = JSON.parse(text).text || "";
                } catch (e) {
                    root.text = "";
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 5000
        onTriggered: if (!poll.running) poll.running = true
    }

    function run(arg) {
        Quickshell.execDetached([ctl, arg]);
        refresh.restart();
    }

    Timer {
        id: refresh
        interval: 400
        onTriggered: if (!poll.running) poll.running = true
    }

    onClicked: m => run(m.button === Qt.RightButton ? "pick" : m.button === Qt.MiddleButton ? "toggle" : "cycle")
}
