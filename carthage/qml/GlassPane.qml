// Frosted glass over moving content: the layers behind the pane (`behind`, bottom first; none
// may contain the pane) are captured live, stacked, blurred and saturated, then clipped to the
// pane's shape. Live capture costs a pass every frame, so it's only for panes with moving content
// behind (the dock over the scrolling tray); panes over the still backdrop use GlassSurface.
//   GlassPane { behind: [backdrop, pages]; shape: shellMask; blurPx: 26 }
import QtQuick
import QtQuick.Effects

Item {
    id: pane

    property var behind: []             // Items, bottom layer first
    property real blurPx: 26
    property real saturation: 0.5       // MultiEffect's scale: 0.5 ≈ CSS saturate(1.5)
    property Item shape: null           // an item drawing the pane's shape in opaque white (pane-sized); a rounded rect if null
    property real radius: 22
    property real captureScale: 1       // < 1 captures at lower resolution (cheaper; the blur hides it)
    // Where the pane is on screen, for the capture to follow it: bind to the moving ancestor's
    // position (a binding can't see an ancestor move by itself).
    property point track: Qt.point(0, 0)

    // The layers it can frost: never one that contains the pane itself (Qt can't capture an item
    // from inside it), e.g. a panel that lives in the pages frosts only the backdrop.
    readonly property var layers: {
        const out = []
        for (const l of behind || []) {
            let inside = false
            for (let q = pane.parent; q; q = q.parent) if (q === l) { inside = true; break }
            if (!inside) out.push(l)
        }
        return out
    }

    // Room around the pane for the blur to pull colour from.
    readonly property real pad: Math.ceil(blurPx)

    Item {
        id: stack
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(Math.ceil(width * pane.captureScale), Math.ceil(height * pane.captureScale))
        x: -pane.pad
        y: -pane.pad
        width: pane.width + 2 * pane.pad
        height: pane.height + 2 * pane.pad
        Repeater {
            model: pane.layers
            ShaderEffectSource {
                required property var modelData
                anchors.fill: parent
                sourceItem: modelData
                live: true
                recursive: false
                textureSize: Qt.size(Math.ceil(width * pane.captureScale), Math.ceil(height * pane.captureScale))
                sourceRect: {
                    if (!modelData) return Qt.rect(0, 0, 0, 0)
                    // (bound to the pane's geometry, so it follows the pane as it moves)
                    const p = pane.mapToItem(modelData, -pane.pad + 0 * pane.x + 0 * pane.y + 0 * pane.width + 0 * pane.track.x,
                                             -pane.pad + 0 * pane.track.y + 0 * pane.height)
                    return Qt.rect(p.x, p.y, width, height)
                }
            }
        }
    }
    Item {
        id: roundMask
        visible: false
        layer.enabled: true
        width: stack.width
        height: stack.height
        Rectangle {
            x: pane.pad
            y: pane.pad
            width: pane.width
            height: pane.height
            radius: pane.radius
            color: "white"
        }
    }
    Item {
        id: shapeMask
        visible: false
        layer.enabled: true
        width: stack.width
        height: stack.height
        ShaderEffectSource {
            x: pane.pad
            y: pane.pad
            width: pane.width
            height: pane.height
            sourceItem: pane.shape
            hideSource: true
        }
    }
    MultiEffect {
        x: stack.x
        y: stack.y
        width: stack.width
        height: stack.height
        source: stack
        autoPaddingEnabled: false
        blurEnabled: true
        // CSS blur(26px) is a Gaussian of that deviation; MultiEffect's blurMax is a radius.
        blurMax: 64
        blur: Math.min(1, pane.blurPx * 2 / 64)
        saturation: pane.saturation
        maskEnabled: true
        maskSource: pane.shape ? shapeMask : roundMask
    }
}
