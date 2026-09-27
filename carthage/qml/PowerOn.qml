// Switching on: a CRT-style line that opens into the picture. `powered` is set when done.
// Skipped with Retro screen effects off, or with no animations.
import QtQuick
import Carthage

Item {
    id: on

    property bool powered: false
    readonly property bool wanted: Backend.settings.crtEffects && Backend.motion > 0

    visible: !powered
    Component.onCompleted: {
        if (wanted) seq.start()
        else powered = true
    }

    Rectangle {
        id: top
        width: parent.width
        height: parent.height / 2
        color: "#050506"
    }
    Rectangle {
        id: bottom
        width: parent.width
        y: parent.height - height
        height: parent.height / 2
        color: "#050506"
    }
    Rectangle {
        id: beam
        anchors.centerIn: parent
        width: 0
        height: 2
        opacity: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: "#e6eeff" }
            GradientStop { position: 0.8; color: "#e6eeff" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        id: glare
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
    }

    SequentialAnimation {
        id: seq
        PauseAnimation { duration: 140 * Backend.motion }
        PropertyAction { target: beam; property: "opacity"; value: 1 }
        NumberAnimation { target: beam; property: "width"; to: on.width; duration: 110 * Backend.motion; easing.type: Easing.OutQuad }
        ParallelAnimation {
            NumberAnimation { target: top; property: "height"; to: 0; duration: 220 * Backend.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: bottom; property: "height"; to: 0; duration: 220 * Backend.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: beam; property: "height"; to: 18; duration: 220 * Backend.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: beam; property: "opacity"; to: 0; duration: 220 * Backend.motion; easing.type: Easing.InQuad }
            SequentialAnimation {
                PropertyAction { target: glare; property: "opacity"; value: 0.14 }
                NumberAnimation { target: glare; property: "opacity"; to: 0; duration: 320 * Backend.motion; easing.type: Easing.OutQuad }
            }
        }
        PropertyAction { target: on; property: "powered"; value: true }
    }
}
