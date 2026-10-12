// A hue slider: its track shows the colour at every hue as it will be drawn (13 colours, 0° to
// 360°), its knob the colour now.
//   HueSlider { track: [...]; swatch: "#4f8fe0"; value: 210; onMoved: … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Slider {
    id: s
    property var track: []
    property color swatch: "transparent"
    readonly property real knob: 20

    from: 0
    to: 359
    stepSize: 1
    snapMode: QQC2.Slider.SnapAlways
    implicitWidth: 200
    implicitHeight: 28
    hoverEnabled: true

    background: Rectangle {  // (inset by half the knob, so the knob sits on its own colour)
        x: s.leftPadding + s.knob / 2
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth - s.knob
        height: 12
        radius: 6
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0 / 12; color: s.track[0] ?? "transparent" }
            GradientStop { position: 1 / 12; color: s.track[1] ?? "transparent" }
            GradientStop { position: 2 / 12; color: s.track[2] ?? "transparent" }
            GradientStop { position: 3 / 12; color: s.track[3] ?? "transparent" }
            GradientStop { position: 4 / 12; color: s.track[4] ?? "transparent" }
            GradientStop { position: 5 / 12; color: s.track[5] ?? "transparent" }
            GradientStop { position: 6 / 12; color: s.track[6] ?? "transparent" }
            GradientStop { position: 7 / 12; color: s.track[7] ?? "transparent" }
            GradientStop { position: 8 / 12; color: s.track[8] ?? "transparent" }
            GradientStop { position: 9 / 12; color: s.track[9] ?? "transparent" }
            GradientStop { position: 10 / 12; color: s.track[10] ?? "transparent" }
            GradientStop { position: 11 / 12; color: s.track[11] ?? "transparent" }
            GradientStop { position: 12 / 12; color: s.track[12] ?? "transparent" }
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.knob
        height: s.knob
        radius: width / 2
        scale: s.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 80 * Backend.motion } }
        color: s.swatch
        border.width: 3
        border.color: "#ffffff"
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: width / 2; color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.35) }
        Rectangle {  // the focus ring
            visible: s.visualFocus
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
    }
}
