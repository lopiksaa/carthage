// An LED with a glow while lit. `light` is the lamp, for pulses; `fade` eases color changes (0
// for sharp flickers).
import QtQuick
import Carthage

Item {
    id: led

    property color color: Backend.theme.p.ledOff
    property real size: 8
    property bool glow: true
    property int fade: 160
    readonly property alias light: lamp
    readonly property bool lit: color.a > 0 && !Qt.colorEqual(color, Backend.theme.p.ledOff)

    width: size
    height: size

    Rectangle {
        visible: led.glow
        anchors.centerIn: parent
        width: Math.round(led.size * 2.25)
        height: width
        radius: width / 2
        color: led.color
        opacity: led.lit ? 0.24 * lamp.opacity : 0
    }
    Rectangle {
        id: lamp
        anchors.fill: parent
        radius: width / 2
        color: led.color
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        Behavior on color {
            enabled: led.fade > 0
            ColorAnimation { duration: led.fade }
        }
    }
}
