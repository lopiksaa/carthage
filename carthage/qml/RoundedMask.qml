// Clips content to rounded corners (`clip` only cuts the square). Use as a layer effect:
//   Rectangle { id: frame; radius: 12; layer.enabled: true; layer.effect: RoundedMask { radius: frame.radius } … }
import QtQuick
import QtQuick.Effects

MultiEffect {
    id: fx

    property real radius: Ui.radiusMedium

    maskEnabled: true
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
    maskSource: shape

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
