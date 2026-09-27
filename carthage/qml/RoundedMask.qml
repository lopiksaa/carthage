// Clips an item's content to rounded corners. Qt's `clip` only cuts to the square outline,
// so images inside a rounded frame kept square corners. Use as the frame's layer effect:
//   Rectangle { id: frame; radius: 12; layer.enabled: true
//               layer.effect: RoundedMask { radius: frame.radius } … }
import QtQuick
import QtQuick.Effects

MultiEffect {
    id: fx

    property real radius: Ui.radiusMedium

    maskEnabled: true
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
    maskSource: shape

    // The mask's shape: hidden, but rendered into a texture (layer) for the effect.
    Item {
        id: shape
        width: fx.width
        height: fx.height
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: fx.radius
            antialiasing: true
        }
    }
}
