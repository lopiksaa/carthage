// Frosted glass over moving content: what's behind the pane (`behind`, which must not contain
// the pane) is captured live, blurred and saturated, clipped to the pane's shape, then tinted.
// Live capture costs a pass every frame, so it's only for panes with moving content behind
// (the dock over the scrolling tray); panes over the still backdrop use a baked look instead.
//   GlassPane { behind: body; shape: shellShape; tint: glass.tint; blurPx: 26 }
import QtQuick
import QtQuick.Effects

Item {
    id: pane

    property Item behind
    property real blurPx: 26
    property real saturation: 0.5       // MultiEffect's scale: 0.5 ≈ CSS saturate(1.5)
    property color tint: "transparent"
    property Item shape: null           // an item drawing the pane's shape in opaque white; a rounded rect if null
    property real radius: 22
    property real captureScale: 1       // < 1 captures at lower resolution (cheaper; the blur hides it)

    // Room around the pane for the blur to pull colour from.
    readonly property real pad: Math.ceil(blurPx)

    ShaderEffectSource {
        id: capture
        visible: false
        sourceItem: pane.behind
        live: true
        recursive: false
        x: -pane.pad
        y: -pane.pad
        width: pane.width + 2 * pane.pad
        height: pane.height + 2 * pane.pad
        textureSize: Qt.size(Math.ceil(width * pane.captureScale), Math.ceil(height * pane.captureScale))
        sourceRect: {
            if (!pane.behind) return Qt.rect(0, 0, 0, 0)
            // (depends on the pane's geometry, so it follows the pane as it moves)
            const p = pane.mapToItem(pane.behind, -pane.pad + 0 * pane.x + 0 * pane.y, -pane.pad)
            return Qt.rect(p.x, p.y, width, height)
        }
    }
    Rectangle {
        id: roundMask
        visible: false
        layer.enabled: true
        width: capture.width
        height: capture.height
        color: "transparent"
        Rectangle {
            x: pane.pad
            y: pane.pad
            width: pane.width
            height: pane.height
            radius: pane.radius
            color: "white"
        }
    }
    MultiEffect {
        x: capture.x
        y: capture.y
        width: capture.width
        height: capture.height
        source: capture
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 32
        blur: Math.min(1, pane.blurPx / 32)
        saturation: pane.saturation
        maskEnabled: true
        maskSource: pane.shape ? pane.shape : roundMask
    }
    Rectangle {  // the tint, in the same shape
        anchors.fill: parent
        radius: pane.radius
        color: pane.tint
        visible: !pane.shape
    }
}
