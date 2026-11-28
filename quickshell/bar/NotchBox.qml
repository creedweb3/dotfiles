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
        // GeometryRenderer + multisampling: the curve renderer anti-aliased the straight bottom edge into
        // a faint half row (1.5px against 2px elsewhere, caught by rice-gapcheck)
        preferredRendererType: Shape.GeometryRenderer
        layer.enabled: true
        layer.samples: 8

        ShapePath {
            fillColor: Theme.boxFill
            strokeColor: root.edge
            strokeWidth: Theme.border
            joinStyle: ShapePath.MiterJoin
            PathSvg {
                // inset by half the line, so it sits inside the box like a Rectangle border
                path: {
                    const w = root.width, h = root.h, d = root.dx, r = root.r, o = Theme.border / 2;
                    if (root.notchRight)
                        return `M${w - d} ${o} H${o} V${h - o} H${w - d} A${r} ${r} 0 0 1 ${w - d} ${o} Z`;
                    return `M${d} ${o} H${w - o} V${h - o} H${d} A${r} ${r} 0 0 0 ${d} ${o} Z`;
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
