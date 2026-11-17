import QtQuick

// Text in the shell's font and colours.
Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
