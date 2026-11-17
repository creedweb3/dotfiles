import QtQuick
import "../common"

// The preset's symbol (already in the accent colour: wallust renders it), `size` pixels tall.
// Theme.symbolPath is a file URL carrying Theme.rev, so a re-rendered symbol loads again.
Image {
    property real size: 24
    height: size
    width: implicitHeight > 0 ? size * implicitWidth / implicitHeight : size
    sourceSize.height: size * 2
    fillMode: Image.PreserveAspectFit
    smooth: true
    cache: false
    source: Theme.symbolPath
}
