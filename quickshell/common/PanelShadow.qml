import QtQuick
import QtQuick.Effects

// Drop shadow under an open panel (Settings > Panels > depth "shadow" or "both"), as the
// demo's box-shadow: 0 12px 32px rgba(0,0,0,.5). Use as `layer.effect` with `layer.enabled`.
MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.5)
    shadowBlur: 1.0
    blurMax: 32
    shadowVerticalOffset: 12
    shadowHorizontalOffset: 0
}
