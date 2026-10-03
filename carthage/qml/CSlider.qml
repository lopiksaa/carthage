// A slider in Carthage's look: a groove cut into the panel, filled with the accent up to a
// plastic knob lit from the top left.
//   CSlider { from: 0; to: 1; value: …; onMoved: … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Slider {
    id: s
    readonly property var pal: Backend.theme.p

    implicitWidth: 200
    implicitHeight: 28
    hoverEnabled: true

    background: Item {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: 6
        Rectangle {  // the groove
            anchors.fill: parent
            radius: 3
            color: Qt.darker(s.pal.panelHover, Backend.theme.dark ? 1.35 : 1.12)
            Rectangle {  // its shaded top edge
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                radius: 1
                color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.35 : 0.12)
            }
        }
        Rectangle {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: Backend.theme.accent.accent
            opacity: s.enabled ? 1 : 0.45
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 20
        height: 20
        radius: 10
        scale: s.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 80 * Backend.motion } }
        gradient: Gradient {
            GradientStop { position: 0; color: s.hovered || s.pressed ? "#ffffff" : "#f4f4f6" }
            GradientStop { position: 1; color: "#d8d8de" }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.28)
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
