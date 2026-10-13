// The panel behind dialogs, pickers and menus. Glass: a live frosted pane over what's behind,
// with a denser tint for reading, a lit top edge and a ring; Plastic: the solid panel.
import QtQuick
import Carthage
import QtQuick.Effects

Item {
    id: panel

    property real radius: 18
    property real shadowOffset: 10
    property real shadowBlur: 32
    property real shadowOpacity: 0.35
    property var frosts: Ui.glassLayers  // what the glass blurs (the setup: only the ground)
    readonly property alias surface: surface
    readonly property bool glassy: Backend.theme.glassy
    readonly property var g: Backend.theme.glass

    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        offset.y: panel.shadowOffset
        blur: panel.shadowBlur
        color: panel.glassy ? panel.g.shadow : Qt.rgba(0, 0, 0, panel.shadowOpacity)
    }
    GlassPane {
        visible: panel.glassy && panel.visible
        anchors.fill: parent
        radius: panel.radius
        behind: visible ? panel.frosts : []
        blurPx: 26
        // (the panel can move — menus open where asked — so the capture follows it)
        track: { const p = panel.mapToItem(null, 0, 0); return Qt.point(p.x + 0 * panel.x, p.y + 0 * panel.y) }
    }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: panel.radius
        color: Backend.theme.p.panel
        border.width: 1
        border.color: Backend.theme.p.panelBorder
    }
    LitEdge {  // glass: the lit top edge, fading down the sides
        visible: panel.glassy
        anchors.fill: parent
        radius: panel.radius
        color: panel.g.edge
    }
}
