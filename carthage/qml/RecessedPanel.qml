// A tray molded into the plastic, shaded inside its top and left lips.
import QtQuick
import QtQuick.Effects
import Carthage

Rectangle {
    id: well
    readonly property bool dark: Backend.theme.dark

    radius: Ui.radiusLarge
    color: Backend.theme.p.panel
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.18)

    // The lip's shade, as one piece so it follows the corner: a thick frame shifted down and
    // right shows only inside the top and left edges; blurred, then cut to the well's shape.
    Item {
        id: shade
        anchors.fill: parent
        anchors.margins: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.35
            blurMax: 12
            maskEnabled: true
            maskSource: shadeMask
        }
        Rectangle {
            readonly property real thick: 24
            x: -thick + 3
            y: -thick + 4
            width: shade.width + 2 * thick
            height: shade.height + 2 * thick
            radius: well.radius + thick
            color: "transparent"
            border.width: thick
            border.color: Qt.rgba(0, 0, 0, well.dark ? 0.4 : 0.12)
        }
    }
    Rectangle {
        id: shadeMask
        anchors.fill: shade
        radius: well.radius - 1
        visible: false
        layer.enabled: true
    }
}
