// A backlit LCD display. In the Classic skin nothing is drawn
// (`bare`). Style the text inside with `ink`, `inkDim` and `fontFamily`.
import QtQuick
import Carthage

Item {
    id: disp

    readonly property bool bare: Backend.theme.skin === "classic"
    readonly property color ink: bare ? Backend.theme.p.dockText : "#1c2710"
    readonly property color inkDim: bare ? Backend.theme.p.dockTextDim : "#4a5c2c"
    readonly property string fontFamily: bare ? "Nunito" : "DotGothic16"
    property bool focused: false
    default property alias content: inner.data

    Rectangle {
        visible: !disp.bare
        anchors.fill: parent
        anchors.margins: -4
        radius: face.radius + 3
        color: "#101014"
    }
    Rectangle {
        visible: disp.focused
        anchors.fill: parent
        anchors.margins: -7
        radius: face.radius + 6
        color: "transparent"
        border.width: 2
        border.color: Ui.focusColor
    }
    Rectangle {
        id: face
        visible: !disp.bare
        anchors.fill: parent
        radius: 7
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#8aaa47" }
            GradientStop { position: 1.0; color: "#9ebf58" }
        }
    }
    Item {
        id: inner
        anchors.fill: face
    }
    Rectangle {
        visible: !disp.bare
        anchors.fill: face
        radius: face.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.3; color: "transparent" }
        }
    }
    Canvas {
        visible: !disp.bare
        anchors.fill: face
        opacity: 0.2
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = "#ffffff"
            c.beginPath()
            c.moveTo(0, 0); c.lineTo(width * 0.34, 0); c.lineTo(width * 0.22, height); c.lineTo(0, height)
            c.closePath(); c.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
