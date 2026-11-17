import QtQuick
import QtQuick.Shapes

// One line icon: an SVG path on a 24 x 24 grid, stroked, scaled to `size`.
Item {
    id: root

    property string path
    property color color: Theme.fg
    property real size: 16
    property real stroke: 2.4    // in grid units, so it scales with the icon

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
