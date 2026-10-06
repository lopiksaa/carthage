// The glass look's ground: a dark or light base with four soft colour fields glowing through
// the panes (Backend.theme.glass: bg, fields, centres). Each field is an ellipse — a circular
// radial gradient squashed to its radii — fading out at 70 %, as in the design handoff.
import QtQuick
import QtQuick.Shapes
import Carthage

Rectangle {
    id: bd

    readonly property var g: Backend.theme.glass

    color: g.bg
    clip: true

    Repeater {
        model: 4
        Item {
            id: fieldItem
            required property int index
            readonly property var c: bd.g.centres[index]
            readonly property color tone: bd.g.fields[index]
            readonly property real rx: Math.max(1, bd.width * c[2])
            readonly property real ry: Math.max(1, bd.height * c[3])
            x: bd.width * c[0] - rx
            y: bd.height * c[1] - ry
            width: 2 * rx
            height: 2 * rx
            transform: Scale { yScale: fieldItem.ry / fieldItem.rx }

            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: fieldItem.rx
                        centerY: fieldItem.rx
                        centerRadius: fieldItem.rx
                        focalX: fieldItem.rx
                        focalY: fieldItem.rx
                        GradientStop { position: 0.0; color: fieldItem.tone }
                        GradientStop { position: 0.7; color: Qt.alpha(fieldItem.tone, 0) }
                    }
                    PathRectangle { width: 2 * fieldItem.rx; height: 2 * fieldItem.rx }
                }
            }
        }
    }
}
