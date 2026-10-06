// A glass pane over the still backdrop (keys, header, search field, panels): tint, a sheen
// fading down from the top, a lit top edge, a 1-px inner ring and a soft outer shadow — the
// handoff's box-shadows, built from items (Qt Quick has no inset shadow). Panes over moving
// content use GlassPane instead (a live blur).
//   GlassSurface { anchors.fill: parent; radius: 12; shadowY: 8; shadowBlur: 18; shadowSpread: -8 }
import QtQuick
import QtQuick.Effects
import Carthage

Item {
    id: gs

    readonly property var g: Backend.theme.glass
    property real radius: 12
    property color tint: g.tint
    property color sheen: g.sheen
    property real sheenEnd: 1.0          // where the sheen has faded out (0–1 of the height)
    property color edge: g.edge
    property color ring: g.ring
    property bool edges: true
    // The outer shadow, as CSS box-shadow: 0 shadowY shadowBlur shadowSpread shadowColor.
    property real shadowY: 8
    property real shadowBlur: 18
    property real shadowSpread: -8
    property color shadowColor: g.shadow
    property bool shadow: true

    Item {  // the outer shadow: the shape, shrunk by the spread, dropped and blurred
        visible: gs.shadow && gs.shadowColor.a > 0
        anchors.fill: parent
        Rectangle {
            id: shadowShape
            visible: false
            x: -gs.shadowSpread
            y: gs.shadowY - gs.shadowSpread
            width: gs.width + 2 * gs.shadowSpread
            height: gs.height + 2 * gs.shadowSpread
            radius: Math.max(0, gs.radius + gs.shadowSpread)
            color: gs.shadowColor
        }
        MultiEffect {
            source: shadowShape
            x: shadowShape.x
            y: shadowShape.y
            width: shadowShape.width
            height: shadowShape.height
            blurEnabled: true
            blurMax: Math.max(1, Math.round(gs.shadowBlur))
            blur: 1
            autoPaddingEnabled: true
        }
    }
    Rectangle {  // the tint
        anchors.fill: parent
        radius: gs.radius
        color: gs.tint
    }
    Rectangle {  // the sheen, top down
        anchors.fill: parent
        radius: gs.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: gs.sheen }
            GradientStop { position: gs.sheenEnd; color: Qt.alpha(gs.sheen, 0) }
        }
    }
    Rectangle {  // the 1-px inner ring
        visible: gs.edges
        anchors.fill: parent
        radius: gs.radius
        color: "transparent"
        border.width: 1
        border.color: gs.ring
    }
    Item {  // the lit top edge: the shape's outline, kept along the top and round the corners
        visible: gs.edges
        anchors.fill: parent
        anchors.bottomMargin: Math.max(0, parent.height - Math.max(3, gs.radius * 0.75))
        clip: true
        Rectangle {
            width: gs.width
            height: gs.height
            radius: gs.radius
            color: "transparent"
            border.width: 1
            border.color: gs.edge
        }
    }
}
