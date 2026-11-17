import QtQuick
import QtQuick.Shapes
import "../common"

// A bar box with a round notch on one side, cut by the hub circle (radius `r`) whose
// centre sits on that edge. The notch arc is outlined, so box and hub read as one shape.
Item {
    id: root

    property bool notchRight: true
    property real r: 22
    property color edge: Theme.line
    default property alias content: holder.data

    readonly property real h: Theme.boxHeight
    // where the circle crosses the top and bottom edges, measured from the notch edge
    readonly property real dx: Math.sqrt(r * r - h * h / 4)

    implicitHeight: h

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.boxFill
            strokeColor: root.edge
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg {
                // half-pixel offsets keep the 1px line crisp
                path: {
                    const w = root.width, h = root.h, d = root.dx, r = root.r;
                    if (root.notchRight)
                        return `M${w - d} 0.5 H0.5 V${h - 0.5} H${w - d} A${r} ${r} 0 0 1 ${w - d} 0.5 Z`;
                    return `M${d} 0.5 H${w - 0.5} V${h - 0.5} H${d} A${r} ${r} 0 0 0 ${d} 0.5 Z`;
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
