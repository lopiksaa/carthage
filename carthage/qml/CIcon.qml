// An interface icon from Carthage's own set (assets/icons/ui, Breeze icons), tinted by the
// image painter (render.py render_icon). Replaces KDE's Kirigami.Icon so the app looks the
// same on every platform:  CIcon { source: "go-next-symbolic"; color: "white"; width: 18; height: 18 }
import QtQuick

Item {
    id: icon

    property string source
    property color color: "black"
    property bool isMask: true // icons are always drawn in one color

    implicitWidth: 16
    implicitHeight: 16

    Image {
        anchors.fill: parent
        // Qt writes colors as #rrggbb or #aarrggbb; the painter reads either.
        source: icon.source ? "image://gc/icon/" + icon.source + "/" + icon.color.toString().replace("#", "") : ""
        sourceSize: Qt.size(Math.ceil(icon.width * Screen.devicePixelRatio), Math.ceil(icon.height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
