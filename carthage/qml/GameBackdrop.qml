// The game's wide art behind the closer look and the store page, fading out downwards. The
// views keep their dark scrim on top, so the text stays readable (≥4.5:1).
import QtQuick
import Carthage

Item {
    id: bd
    property string source
    property real level: 1

    Image {
        id: img
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(parent.height * 0.75, width * 0.42)
        source: bd.source
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignTop
        asynchronous: true
        cache: true
        sourceSize.width: 1280
        opacity: status === Image.Ready ? bd.level : 0
        Behavior on opacity { NumberAnimation { duration: 260 * Backend.motion } }
    }
    // Fade the art into the backdrop below it.
    Rectangle {
        anchors.left: img.left
        anchors.right: img.right
        anchors.bottom: img.bottom
        height: img.height * 0.6
        opacity: img.opacity
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.04, 0.04, 0.05, 1) }
        }
    }
}
