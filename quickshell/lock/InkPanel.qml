import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Manga.js" as Manga

// One manga panel: a frame image cut to the panel's polygon and printed in the lock's ink
// (ink.frag: grey, then black -> shadow, white -> highlight), with an ink outline.
// Without the compiled shader it falls back to plain grey (or colour) panels.
Item {
    id: pnl

    required property var poly        // [[x, y], ...] in page coordinates
    required property int index
    property url source
    property bool closeUp: false      // whole pages / wallpapers: zoom in on a different spot each
    property var ink                  // Manga.inks()
    property bool spot: false         // spot ink: this panel is printed in the accent
    property url shader               // compiled ink.frag.qsb, or "" for the fallback
    property color line: "#111111"

    readonly property var bb: Manga.bbox(poly)
    readonly property var pts: poly.map(q => Qt.point(q[0] - bb.x, q[1] - bb.y)).concat([Qt.point(poly[0][0] - bb.x, poly[0][1] - bb.y)])
    readonly property color shadowC: Qt.rgba((spot ? ink.spotShadow : ink.shadow)[0], (spot ? ink.spotShadow : ink.shadow)[1], (spot ? ink.spotShadow : ink.shadow)[2], 1)
    readonly property color highC: Qt.rgba((spot ? ink.spotHighlight : ink.highlight)[0], (spot ? ink.spotHighlight : ink.highlight)[1], (spot ? ink.spotHighlight : ink.highlight)[2], 1)

    x: bb.x
    y: bb.y
    width: bb.w
    height: bb.h

    // the polygon, as an alpha mask for the image
    Shape {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            PathPolyline { path: pnl.pts }
        }
    }

    // the frame: a single panel just fills its frame; whole pages get a close-up
    Item {
        id: pic
        anchors.fill: parent
        clip: true
        visible: false
        layer.enabled: true
        Image {
            readonly property real zoom: pnl.closeUp ? Math.max(1, 620 / Math.max(pnl.width, pnl.height, 1)) : 1.08
            readonly property real fx: (pnl.index * 37 % 10) / 10
            readonly property real fy: (pnl.index * 53 % 10) / 10
            width: pnl.width * zoom
            height: pnl.height * zoom
            x: -(width - pnl.width) * fx
            y: -(height - pnl.height) * fy
            source: pnl.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        }
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: pnl.shader.toString() !== "" && status !== ShaderEffect.Error
        property var source: pic
        property var maskSource: mask
        property color shadow: pnl.shadowC
        property color highlight: pnl.highC
        property real colour: pnl.ink.colour ? 1 : 0
        fragmentShader: pnl.shader
    }

    MultiEffect {
        anchors.fill: parent
        visible: !fx.visible
        source: pic
        saturation: pnl.ink.colour ? 0 : -1
        maskEnabled: true
        maskSource: mask
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: pnl.line
            strokeWidth: 3
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: pnl.pts }
        }
    }
}
