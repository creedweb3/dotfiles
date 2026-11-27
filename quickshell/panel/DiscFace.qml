import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../common"

// One CD for the disc shelf: the cover printed over the whole disc, a clear hub with its hole,
// a fixed sheen and a rim. No cover: a blank dark disc with grooves.
Item {
    id: root

    property string source: ""
    property bool spinning: false
    property color rim: Theme.accent

    readonly property real d: Math.min(width, height)

    Item {
        id: face
        width: root.d
        height: root.d
        anchors.centerIn: parent

        RotationAnimation on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: face.rotation
            to: face.rotation + 360
            duration: 9000
        }

        // blank disc
        Rectangle {
            visible: root.source === ""
            anchors.fill: parent
            radius: width / 2
            color: Theme.panel
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (0.9 - index * 0.12)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.07)
                }
            }
        }

        // the cover, cut round
        Image {
            id: img
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            sourceSize: Qt.size(root.d * 2, root.d * 2)
            visible: false
            layer.enabled: true
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            visible: root.source !== ""
            anchors.fill: parent
            source: img
            maskEnabled: true
            maskSource: mask
        }

        // hub: a faint ring, the clear centre, the hole
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.34
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.2)
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.22
            height: width
            radius: width / 2
            color: Theme.alpha(Theme.bg, 0.7)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.3)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.4
                height: width
                radius: width / 2
                color: Theme.bg
            }
        }
    }

    // light catching the disc: off, its wedge edges read as lines cutting across the art
    Shape {
        visible: false
        width: root.d
        height: root.d
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: root.d / 2
                centerY: root.d / 2
                angle: 30
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.10; color: Qt.rgba(1, 1, 1, 0.18) }
                GradientStop { position: 0.20; color: "transparent" }
                GradientStop { position: 0.50; color: "transparent" }
                GradientStop { position: 0.60; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.70; color: "transparent" }
                GradientStop { position: 1.00; color: "transparent" }
            }
            PathAngleArc {
                centerX: root.d / 2
                centerY: root.d / 2
                radiusX: root.d / 2
                radiusY: root.d / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
    Rectangle {
        width: root.d
        height: root.d
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.rim
    }
}
