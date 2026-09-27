// The floating panel used by Carthage's dialogs, pickers and menus: a rounded panel in the
// hardware's colors with a soft drop shadow.
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

    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        offset.y: panel.shadowOffset
        blur: panel.shadowBlur
        color: Qt.rgba(0, 0, 0, panel.shadowOpacity)
    }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: panel.radius
        color: Backend.theme.p.panel
        border.width: 1
        border.color: Backend.theme.p.panelBorder
    }
}
