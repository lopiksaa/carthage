// A tray molded into the plastic, shaded inside its top and left lips.
import QtQuick
import Carthage

Rectangle {
    readonly property bool dark: Backend.theme.dark

    radius: Ui.radiusLarge
    color: Backend.theme.p.panel
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.18)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 14
        radius: Ui.radiusLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, dark ? 0.35 : 0.1) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 1
        width: 10
        radius: Ui.radiusLarge
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, dark ? 0.3 : 0.08) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
