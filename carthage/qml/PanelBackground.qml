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
        behind: visible ? Ui.glassLayers : []
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
    Item {  // glass: the lit top edge
        visible: panel.glassy
        anchors.fill: parent
        anchors.bottomMargin: Math.max(0, parent.height - panel.radius * 0.75)
        clip: true
        Rectangle {
            width: panel.width
            height: panel.height
            radius: panel.radius
            color: "transparent"
            border.width: 1
            border.color: panel.g.edge
        }
    }
}
