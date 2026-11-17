// SDDM login screen for the rice (Qt 6 greeter, sddm >= 0.21): the lock screen's manga page.
// The screen is cut into manga panels printed in the lock's ink; the big middle panel holds the
// day, time, date, the password box, the user and the power buttons. The session is always Hyprland.
// `sudo boot-theme` fills this folder: theme.conf (colours and the lock screen's settings), frames/
// (the panel images), symbol.png, and Manga.js, InkPanel.qml and ink.frag.qsb from quickshell/lock.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Manga.js" as Manga

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#111111"

    readonly property real s: height / 858          // the demo's sizes are for an 858px tall desk
    readonly property string face: config.font || "JetBrainsMono Nerd Font"
    function opt(k, d) { const v = config[k]; return v === undefined || v === null || String(v) === "" ? d : String(v) }
    function shown(k) { return opt(k, "on") === "on" }

    // the page: "random" picks a new style and cut on every start
    readonly property string pref: opt("mpg", "grid")
    readonly property string style: pref === "random" ? Manga.STYLES[Math.floor(Math.random() * Manga.STYLES.length)] : pref
    readonly property int seed: pref === "random" ? Math.floor(Math.random() * 100000) : 0
    readonly property var cut: Manga.page(width, height, style, Number(opt("mfr", "56")), seed)
    readonly property var panels: cut.panels
    readonly property int ti: cut.ti
    // the time panel; null while the cut is rebuilt and ti points past the new panel list
    readonly property var tp: ti >= 0 && ti < panels.length ? panels[ti] : null
    readonly property int frameCount: Number(opt("frameCount", "0"))
    readonly property color accent: opt("accent", "#e8e8e8")
    readonly property color accent2: opt("accent2", "#9e9e9e")
    readonly property color bg: opt("bg", "#0d0d0d")
    readonly property var ink: Manga.inks(opt("mink", "night"), opt("macc", "time"), Manga.rgb(accent), Manga.rgb(accent2), Manga.rgb(bg))
    readonly property color mga: ink.mono ? "#f6f3ec" : accent
    function c(a) { return Qt.rgba(a[0], a[1], a[2], 1) }
    // which frame panel i shows (the time panel takes none)
    function frameFor(i) {
        if (frameCount < 1) return ""
        const k = i < ti || ti < 0 ? i : i - 1
        return Qt.resolvedUrl("frames/" + (k % frameCount) + ".jpg")
    }

    // ---- login
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string message: ""
    property bool failed: false
    // the Hyprland session (plain Hyprland before a uwsm-managed one), else the last used
    readonly property int sessionIndex: {
        let best = -1
        for (let i = 0; i < sessions.count; i++) {
            const it = sessions.itemAt(i)
            if (!it || !/hyprland/i.test(it.name + " " + it.file)) continue
            if (best < 0 || !/uwsm/i.test(it.name + " " + it.file)) best = i
            if (!/uwsm/i.test(it.name + " " + it.file)) break
        }
        return best >= 0 ? best : (sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0)
    }
    function login() {
        if (pw.text.length === 0) { fail("type your password first"); return }
        message = "logging in…"; failed = false
        sddm.login(users.itemAt(userIndex).name, pw.text, sessionIndex)
    }
    function fail(text) { message = text; failed = true; shake.restart() }

    Connections {
        target: sddm
        function onLoginFailed() { pw.text = ""; root.fail("wrong password · try again") }
    }

    // user and session names, read from the models once each
    Repeater { id: users; model: userModel; Item { property string name: model.name } }
    Repeater { id: sessions; model: sessionModel; Item { property string name: model.name; property string file: model.file || "" } }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // ---- the page
    Rectangle { anchors.fill: parent; color: root.c(root.ink.gutter) }

    Repeater {
        model: root.panels.length
        Loader {
            required property int index
            id: ld
            active: index !== root.ti
            sourceComponent: InkPanel {
                poly: root.panels[ld.index]
                index: ld.index
                source: root.frameFor(ld.index)
                closeUp: root.opt("hasFrames", "no") !== "yes"
                ink: root.ink
                spot: root.opt("mink", "night") === "spot" && ld.index % 5 === 2
                shader: root.opt("shader", "") ? Qt.resolvedUrl(root.opt("shader", "")) : ""
                line: root.c(root.ink.line)
            }
        }
    }

    Shape {   // the time panel
        visible: root.tp !== null
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.c(root.ink.time)
            strokeColor: root.c(root.ink.timeStroke)
            strokeWidth: 3
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: root.tp ? root.tp.map(q => Qt.point(q[0], q[1])).concat([Qt.point(root.tp[0][0], root.tp[0][1])]) : []
            }
        }
    }

    Item {
        id: box
        readonly property var bb: root.tp ? Manga.bbox(root.tp) : { x: 0, y: 0, w: root.width, h: root.height }
        x: bb.x + bb.w * .12
        y: bb.y + bb.h * .08
        width: bb.w * .76
        height: bb.h * .84

        // the clock size only knows the panel box: shrink it until the other rows fit, then scale the block
        readonly property real fs: Math.round(Math.min(bb.w / 4.4, bb.h / 3.4, 170))
        readonly property real rest: above.implicitHeight + below.implicitHeight + 14 * root.s
        readonly property real timeSize: Math.max(Math.max(40, fs * .65), Math.min(fs, height - rest))
        readonly property real fit: Math.min(1, height / (rest + timeSize))

        Column {
            width: parent.width
            anchors.centerIn: parent
            scale: box.fit

            Column {
                id: above
                width: parent.width
                spacing: 12 * root.s

                Item {   // the preset symbol, in the time panel's ink
                    visible: root.opt("mlsym", "off") === "on"
                    width: parent.width
                    height: 46 * root.s
                    Image {
                        id: symImg
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: parent.height
                        fillMode: Image.PreserveAspectFit
                        source: config.symbol || "symbol.png"
                        sourceSize.height: height
                        visible: false
                        layer.enabled: true
                    }
                    Rectangle {
                        anchors.fill: symImg
                        color: root.mga
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: symImg }
                    }
                }

                Loader {   // the day label (mday)
                    visible: root.shown("mlday")
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: ({ tag: tagC, plain: plainC, rule: ruleC, kanji: kanjiC, mix: mixC })[root.opt("mday", "mix")] || tagC
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8 * root.s
                bottomPadding: 6 * root.s
                text: Qt.formatTime(root.now, "hh:mm")
                font { family: root.face; pixelSize: box.timeSize; weight: Font.Black; letterSpacing: -box.timeSize * .04 }
                lineHeight: 1
                color: "#f6f3ec"
            }

            Column {
                id: below
                width: parent.width

                Text {
                    visible: root.shown("mldate")
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Manga.dateText(root.now, root.opt("mdt", "long")).toUpperCase()
                    font { family: root.face; pixelSize: 12 * root.s; letterSpacing: 3 * root.s }
                    color: "#9a9a9a"
                }

                Item { width: 1; height: 14 * root.s }
                Rectangle {   // the password box
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * .72
                    height: 16 * root.s + 12 * root.s
                    color: "transparent"
                    border { width: 2; color: root.failed ? root.opt("crit", "#e5534b") : root.mga }
                    transform: Translate { id: shakeX }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: shakeX; property: "x"; to: -6 * root.s; duration: 60 }
                        NumberAnimation { target: shakeX; property: "x"; to: 6 * root.s; duration: 120 }
                        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                    }
                    TextInput {
                        id: pw
                        anchors { left: parent.left; right: parent.right; leftMargin: 10 * root.s; rightMargin: 10 * root.s; verticalCenter: parent.verticalCenter }
                        color: "#f6f3ec"
                        selectionColor: root.mga
                        font { family: root.face; pixelSize: 14 * root.s; letterSpacing: 4 * root.s }
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        passwordMaskDelay: 0
                        cursorDelegate: Text {   // the lock's block caret
                            text: "▌"
                            color: "#f6f3ec"
                            font: pw.font
                        }
                        clip: true
                        focus: true
                        Component.onCompleted: forceActiveFocus()
                        onTextEdited: if (root.failed) { root.failed = false; root.message = "" }
                        Keys.onReturnPressed: root.login()
                        Keys.onEnterPressed: root.login()
                        Keys.onEscapePressed: text = ""
                    }
                }

                // the user (click to switch when there is more than one) and the power buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 12 * root.s
                    spacing: 14 * root.s

                    Text {
                        color: "#f6f3ec"
                        textFormat: Text.StyledText
                        font { family: root.face; pixelSize: 12 * root.s; letterSpacing: 2 * root.s; bold: true }
                        text: "<font color=\"" + root.mga + "\"></font>&nbsp;&nbsp;" + (users.count ? users.itemAt(root.userIndex).name : "")
                        MouseArea {
                            anchors.fill: parent
                            enabled: users.count > 1
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { root.userIndex = (root.userIndex + 1) % users.count; pw.text = ""; pw.forceActiveFocus() }
                        }
                    }
                    Repeater {
                        model: [
                            { glyph: "", tip: "sleeping…", ok: sddm.canSuspend, act: "sleep" },
                            { glyph: "", tip: "restarting…", ok: sddm.canReboot, act: "restart" },
                            { glyph: "", tip: "shutting down…", ok: sddm.canPowerOff, act: "off" }
                        ]
                        Text {
                            required property var modelData
                            visible: modelData.ok
                            color: area.containsMouse ? root.mga : "#9a9a9a"
                            font { family: root.face; pixelSize: 12 * root.s }
                            text: modelData.glyph
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                anchors.margins: -6 * root.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.failed = false
                                    root.message = parent.modelData.tip
                                    if (parent.modelData.act === "sleep") sddm.suspend()
                                    else if (parent.modelData.act === "restart") sddm.reboot()
                                    else sddm.powerOff()
                                }
                            }
                        }
                    }
                }

                Text {   // "enter to log in", or what went wrong
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 10 * root.s
                    text: root.message || "enter to log in"
                    font { family: root.face; pixelSize: 10 * root.s; letterSpacing: 2 * root.s }
                    color: root.failed ? root.opt("crit", "#e5534b") : "#6a6a6a"
                }
            }
        }
    }

    // the day label styles (mday), as the lock's MangaPage.qml
    Component {   // tag: a skewed paper label
        id: tagC
        Rectangle {
            implicitWidth: tagT.implicitWidth + 32 * root.s
            implicitHeight: tagT.implicitHeight + 8 * root.s
            color: root.mga
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2126, 0, 0.2126 * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            Text {
                id: tagT
                anchors.centerIn: parent
                text: Manga.weekday(root.now)
                font { family: root.face; pixelSize: 14 * root.s; letterSpacing: 6 * root.s; bold: true }
                color: "#111111"
            }
        }
    }
    Component {
        id: plainC
        Text {
            text: Manga.weekday(root.now)
            font { family: root.face; pixelSize: 15 * root.s; letterSpacing: 12 * root.s; bold: true }
            color: root.mga
        }
    }
    Component {   // rule: the day between two accent rules
        id: ruleC
        Row {
            spacing: 14 * root.s
            Rectangle { width: 42 * root.s; height: 2; color: root.mga; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: Manga.weekday(root.now)
                font { family: root.face; pixelSize: 13 * root.s; letterSpacing: 8 * root.s; bold: true }
                color: root.mga
            }
            Rectangle { width: 42 * root.s; height: 2; color: root.mga; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Component {   // kanji: the Japanese day, the English day small underneath
        id: kanjiC
        Column {
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Manga.kanjiDay(root.now)
                font { family: root.face; pixelSize: 26 * root.s; letterSpacing: 6 * root.s; bold: true }
                color: root.mga
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 2 * root.s
                text: Manga.weekday(root.now)
                font { family: root.face; pixelSize: 10 * root.s; letterSpacing: 6 * root.s }
                color: "#9a9a9a"
            }
        }
    }
    Component {   // mix: kanji between two rules, the English day centred underneath
        id: mixC
        Column {
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * root.s
                Rectangle { width: 52 * root.s; height: 2; color: root.mga; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: Manga.kanjiDay(root.now)
                    leftPadding: 6 * root.s
                    font { family: root.face; pixelSize: 26 * root.s; letterSpacing: 6 * root.s; bold: true }
                    color: root.mga
                }
                Rectangle { width: 52 * root.s; height: 2; color: root.mga; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 7 * root.s
                leftPadding: 7 * root.s
                text: Manga.weekday(root.now)
                font { family: root.face; pixelSize: 10 * root.s; letterSpacing: 7 * root.s }
                color: "#9a9a9a"
            }
        }
    }
}
