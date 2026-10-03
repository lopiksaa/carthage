// The game's wide art behind the closer look and the store page. The image itself fades out
// towards the bottom (a gradient mask), so it melts into whatever is below with no edge.
// The views keep their dark scrim on top, so the text stays readable.
import QtQuick
import QtQuick.Effects
import Carthage

Item {
    id: bd
    property string source
    property real level: 1

    Image {
        id: img
        anchors.fill: parent
        source: bd.source
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignTop
        asynchronous: true
        cache: true
        sourceSize.width: 1600
        visible: false
    }
    Rectangle {
        id: fade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "white" }
            GradientStop { position: 0.35; color: "white" }
            GradientStop { position: 0.9; color: "transparent" }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready && opacity > 0.01
        opacity: img.status === Image.Ready ? bd.level : 0
        Behavior on opacity { NumberAnimation { duration: 260 * Backend.motion } }
        maskEnabled: true
        maskSource: fade
        maskThresholdMin: 0.0
        maskSpreadAtMin: 1.0
    }
}
