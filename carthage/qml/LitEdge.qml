// Glass's lit rim, as light really catches an edge: brightest at the top-left corner (where the
// light comes from) and fading smoothly away from it in every direction, a softer glow at the
// bottom-right corner where the light comes back out, and only a faint line in between. Painted
// with gradients round the corners, in pixels, so a small button and a wide panel match; drawn
// just inside the shape (a reflection is on the glass, not an added outline).
//   LitEdge { anchors.fill: parent; radius: 12; color: Backend.theme.glass.edge }
import QtQuick
import QtQuick.Shapes

Shape {
    id: le

    property real radius: 12
    property color color: "white"
    readonly property real reach: Math.min(110, (width + height) * 0.4)    // how far the main light carries
    readonly property real glow: Math.min(70, (width + height) * 0.25)     // and the glow at the far corner
    function tone(k) { return Qt.alpha(le.color, Math.min(1, le.color.a * 2.2 * k)) }  // (the corner catches more than the flat edge)

    preferredRendererType: Shape.CurveRenderer
    component Rim: ShapePath {
        fillColor: "transparent"
        strokeWidth: 0.6
        PathRectangle { x: 0.3; y: 0.3; width: le.width - 0.6; height: le.height - 0.6; radius: Math.max(0, le.radius - 0.3) }
    }
    Rim { strokeColor: le.tone(0.1) }  // the faint line all round
    Rim {
        strokeColor: "transparent"
        strokeGradient: RadialGradient {
            centerX: 0; centerY: 0; centerRadius: le.reach
            focalX: 0; focalY: 0
            GradientStop { position: 0.0; color: le.tone(1) }
            GradientStop { position: 0.4; color: le.tone(0.55) }
            GradientStop { position: 1.0; color: le.tone(0) }
        }
    }
    Rim {
        strokeColor: "transparent"
        strokeGradient: RadialGradient {
            centerX: le.width; centerY: le.height; centerRadius: le.glow
            focalX: le.width; focalY: le.height
            GradientStop { position: 0.0; color: le.tone(0.5) }
            GradientStop { position: 1.0; color: le.tone(0) }
        }
    }
}
