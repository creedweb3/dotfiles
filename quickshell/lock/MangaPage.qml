import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../common"
import "Manga.js" as Manga

// The manga lock page (the demo's mgLock): the screen cut into panels, each a manga frame of the
// current series printed in the chosen ink; the largest middle panel is the inked time panel with
// the day, time, date, password, hint, music line and notification count.
// Used full size by the lock and scaled down by Settings > Lock screen's preview.
Item {
    id: page

    required property LockData lockData
    property string style: Prefs.mpg === "random" ? "grid" : Prefs.mpg
    property int seed: 0              // extra randomness for "random" (a new cut every lock)
    property int shift: 0             // which frame the first panel shows (a new mix every lock)
    property url shader: ""
    property date now: new Date()
    property string typed: ""         // what the password box shows (dots)
    property string message: ""       // pam message (wrong password, faillock)
    property int shakeTick: 0
    property int notifs: 0
    property var spectrum: []
    property var player: null         // MprisPlayer
    property bool interactive: true

    readonly property real s: height / 858   // the demo's text sizes are for an 858px tall desk
    readonly property var cut: width > 0 && height > 0 ? Manga.page(width, height, style, Prefs.mfr, seed) : { panels: [], ti: -1 }
    readonly property var panels: cut.panels
    readonly property int ti: cut.ti
    // the time panel; null while the cut is rebuilt and ti points past the new panel list
    readonly property var tp: ti >= 0 && ti < panels.length ? panels[ti] : null
    readonly property var ink: Manga.inks(Prefs.mink, Prefs.macc, Manga.rgb(Theme.accent), Manga.rgb(Theme.accent2), Manga.rgb(Theme.bg))
    readonly property color mga: ink.mono ? "#f6f3ec" : Theme.accent
    readonly property var pool: lockData.pool.length ? lockData.pool.slice(shift % lockData.pool.length).concat(lockData.pool.slice(0, shift % lockData.pool.length)) : []

    function c(a) { return Qt.rgba(a[0], a[1], a[2], 1) }
    function shown(k) { return Prefs[k] === "on" }
    // which pool image panel i shows (the time panel takes no image)
    function frameFor(i) {
        if (!pool.length) return ""
        const k = i < ti || ti < 0 ? i : i - 1
        return pool[k % pool.length]
    }

    Rectangle {   // the gutters
        anchors.fill: parent
        color: page.c(page.ink.gutter)
    }

    Repeater {
        model: page.panels.length
        Loader {
            required property int index
            id: ld
            active: index !== page.ti
            sourceComponent: InkPanel {
                poly: page.panels[ld.index]
                index: ld.index
                source: page.frameFor(ld.index)
                closeUp: !page.lockData.hasFrames
                ink: page.ink
                spot: Prefs.mink === "spot" && ld.index % 5 === 2
                shader: page.shader
                line: page.c(page.ink.line)
            }
        }
    }

    // the time panel
    Shape {
        id: timeShape
        visible: page.tp !== null
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: page.c(page.ink.time)
            strokeColor: page.c(page.ink.timeStroke)
            strokeWidth: 3
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: page.tp ? page.tp.map(q => Qt.point(q[0], q[1])).concat([Qt.point(page.tp[0][0], page.tp[0][1])]) : []
            }
        }
    }

    Item {
        id: box
        readonly property var bb: page.tp ? Manga.bbox(page.tp) : { x: 0, y: 0, w: page.width, h: page.height }
        x: bb.x + bb.w * .12
        y: bb.y + bb.h * .08
        width: bb.w * .76
        height: bb.h * .84
        clip: true

        // the clock size only knows the panel box: shrink it until the other rows fit, then scale the block
        readonly property real fs: Math.round(Math.min(bb.w / 4.4, bb.h / 3.4, 170))
        readonly property real rest: above.implicitHeight + below.implicitHeight + 14 * page.s
        readonly property real timeSize: Math.max(Math.max(40, fs * .65), Math.min(fs, height - rest))
        readonly property real fit: Math.min(1, height / (rest + timeSize))

        Column {
            id: inner
            width: parent.width
            anchors.centerIn: parent
            scale: box.fit

            Column {
                id: above
                width: parent.width
                spacing: 12 * page.s

                Item {   // the preset symbol, in the time panel's ink
                    visible: page.shown("mlsym")
                    width: parent.width
                    height: 46 * page.s
                    Image {
                        id: symImg
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: parent.height
                        fillMode: Image.PreserveAspectFit
                        source: Theme.symbolPath
                        sourceSize.height: height
                        visible: false
                        layer.enabled: true
                    }
                    Rectangle {
                        anchors.fill: symImg
                        color: page.mga
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: symImg }
                    }
                }

                Loader {   // the day label (mday)
                    visible: page.shown("mlday")
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: ({ tag: tagC, plain: plainC, rule: ruleC, kanji: kanjiC, mix: mixC })[Prefs.mday] || tagC
                }
            }

            Text {
                id: tm
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8 * page.s
                bottomPadding: 6 * page.s
                text: Qt.formatTime(page.now, "hh:mm")
                font { family: Theme.fontFamily; pixelSize: box.timeSize; weight: Font.Black; letterSpacing: -box.timeSize * .04 }
                lineHeight: 1
                color: "#f6f3ec"
            }

            Column {
                id: below
                width: parent.width
                spacing: 0

                Text {
                    visible: page.shown("mldate")
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Manga.dateText(page.now, Prefs.mdt).toUpperCase()
                    font { family: Theme.fontFamily; pixelSize: 12 * page.s; letterSpacing: 3 * page.s }
                    color: "#9a9a9a"
                }

                Item { width: 1; height: 14 * page.s }
                Rectangle {   // the password box: a dot per typed character and a caret
                    id: pw
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * .72
                    height: pwText.implicitHeight + 12 * page.s
                    color: "transparent"
                    border { width: 2; color: page.mga }
                    Text {
                        id: pwText
                        anchors { left: parent.left; leftMargin: 10 * page.s; verticalCenter: parent.verticalCenter }
                        text: page.typed + "▌"
                        font { family: Theme.fontFamily; pixelSize: 14 * page.s; letterSpacing: 4 * page.s }
                        color: "#f6f3ec"
                    }
                    transform: Translate { id: shakeX }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: shakeX; property: "x"; to: -6 * page.s; duration: 60 }
                        NumberAnimation { target: shakeX; property: "x"; to: 6 * page.s; duration: 120 }
                        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                    }
                    Connections {
                        target: page
                        function onShakeTickChanged() { shake.restart() }
                    }
                }

                Text {   // pam's last message (wrong password, too many tries)
                    visible: page.message !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 8 * page.s
                    text: page.message
                    font { family: Theme.fontFamily; pixelSize: 11 * page.s; letterSpacing: 1 * page.s }
                    color: "#e5534b"
                }

                Text {
                    visible: page.shown("mlhint")
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 8 * page.s
                    text: "type your password + enter to unlock"
                    font { family: Theme.fontFamily; pixelSize: 10 * page.s; letterSpacing: 2 * page.s }
                    color: "#6a6a6a"
                }

                // the hint line (mhint): the preset's quote, the chapter on show, or an accent rule
                Text {
                    readonly property string chapter: Manga.chapterAt(page.lockData.manifest, page.lockData.preset, page.now.getMinutes())
                    visible: page.shown("mlquote") && text !== "" && Prefs.mhint !== "rule"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, parent.width * .9)
                    topPadding: 12 * page.s
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Prefs.mhint === "quote" && page.lockData.info.quote ? "“" + page.lockData.info.quote + "”"
                        : Prefs.mhint === "chapter" && chapter ? String(page.lockData.info.label).toUpperCase() + " · CHAPTER " + chapter : ""
                    font { family: Theme.fontFamily; pixelSize: (Prefs.mhint === "chapter" ? 11 : 12) * page.s
                        letterSpacing: (Prefs.mhint === "chapter" ? 4 : 1) * page.s; italic: Prefs.mhint === "quote" }
                    color: "#9a9a9a"
                }
                Item {
                    visible: page.shown("mlquote") && Prefs.mhint === "rule"
                    width: parent.width
                    height: 16 * page.s
                    Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * .38; height: 2; color: page.mga }
                }

                Item {
                    visible: page.shown("mlmusic") && page.player !== null && page.player.trackTitle !== ""
                    width: parent.width
                    height: visible ? music.implicitHeight + 16 * page.s : 0
                    LockMusic {
                        id: music
                        y: 16 * page.s
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * .88
                        s: page.s
                        style: Prefs.mmus
                        accent: page.mga
                        title: page.player ? page.player.trackTitle : ""
                        artist: page.player ? page.player.trackArtist : ""
                        playing: page.player ? page.player.isPlaying : false
                        values: page.spectrum
                        enabled: page.interactive
                        onPrev: if (page.player && page.player.canGoPrevious) page.player.previous()
                        onToggle: if (page.player && page.player.canTogglePlaying) page.player.togglePlaying()
                        onNext: if (page.player && page.player.canGoNext) page.player.next()
                    }
                }

                Text {
                    visible: page.shown("mlnotif") && page.notifs > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 14 * page.s
                    text: "<font color=\"" + page.mga + "\"><b>" + page.notifs + "</b></font> notification" + (page.notifs === 1 ? "" : "s")
                    textFormat: Text.StyledText
                    font { family: Theme.fontFamily; pixelSize: 11 * page.s; letterSpacing: 2 * page.s }
                    color: "#9a9a9a"
                }
            }
        }
    }

    // the day label styles (mday)
    Component {   // tag: a skewed paper label
        id: tagC
        Rectangle {
            implicitWidth: tagT.implicitWidth + 32 * page.s
            implicitHeight: tagT.implicitHeight + 8 * page.s
            color: page.mga
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2126, 0, 0.2126 * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            Text {
                id: tagT
                anchors.centerIn: parent
                text: Manga.weekday(page.now)
                font { family: Theme.fontFamily; pixelSize: 14 * page.s; letterSpacing: 6 * page.s; bold: true }
                color: "#111111"
            }
        }
    }
    Component {
        id: plainC
        Text {
            text: Manga.weekday(page.now)
            font { family: Theme.fontFamily; pixelSize: 15 * page.s; letterSpacing: 12 * page.s; bold: true }
            color: page.mga
        }
    }
    Component {   // rule: the day between two accent rules
        id: ruleC
        Row {
            spacing: 14 * page.s
            Rectangle { width: 42 * page.s; height: 2; color: page.mga; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: Manga.weekday(page.now)
                font { family: Theme.fontFamily; pixelSize: 13 * page.s; letterSpacing: 8 * page.s; bold: true }
                color: page.mga
            }
            Rectangle { width: 42 * page.s; height: 2; color: page.mga; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Component {   // kanji: the Japanese day, the English day small underneath
        id: kanjiC
        Column {
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Manga.kanjiDay(page.now)
                font { family: Theme.fontFamily; pixelSize: 26 * page.s; letterSpacing: 6 * page.s; bold: true }
                color: page.mga
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 2 * page.s
                text: Manga.weekday(page.now)
                font { family: Theme.fontFamily; pixelSize: 10 * page.s; letterSpacing: 6 * page.s }
                color: "#9a9a9a"
            }
        }
    }
    Component {   // mix (rule + kanji): kanji between two rules, the English day centred underneath
        id: mixC
        Column {
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * page.s
                Rectangle { width: 52 * page.s; height: 2; color: page.mga; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: Manga.kanjiDay(page.now)
                    leftPadding: 6 * page.s
                    font { family: Theme.fontFamily; pixelSize: 26 * page.s; letterSpacing: 6 * page.s; bold: true }
                    color: page.mga
                }
                Rectangle { width: 52 * page.s; height: 2; color: page.mga; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 7 * page.s
                leftPadding: 7 * page.s
                text: Manga.weekday(page.now)
                font { family: Theme.fontFamily; pixelSize: 10 * page.s; letterSpacing: 7 * page.s }
                color: "#9a9a9a"
            }
        }
    }
}
