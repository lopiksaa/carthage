// A backlit display: an LCD (Plastic skin) or a VFD (Hi-Fi). In Classic nothing is drawn
// (`bare`). Style the text inside with `ink`, `inkDim` and `fontFamily`.
import QtQuick
import QtQuick.Effects
import Carthage

Item {
    id: disp

    readonly property bool vfd: Backend.theme.skin === "hifi"
    readonly property bool bare: Backend.theme.skin === "classic"
    readonly property color ink: vfd ? "#6ff5d6" : bare ? Backend.theme.p.dockText : "#1c2710"
    readonly property color inkDim: vfd ? "#3e9a86" : bare ? Backend.theme.p.dockTextDim : "#4a5c2c"
    readonly property string fontFamily: vfd ? "VT323" : bare ? "Nunito" : "DotGothic16"
    // VT323 is drawn smaller than DotGothic16 at the same size: sizes set on this scale.
    function fontPx(px) { return Math.round(vfd ? px * 1.3 : px) }
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
        radius: disp.vfd ? 4 : 7
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: disp.vfd ? "#0c1413" : "#8aaa47" }
            GradientStop { position: 1.0; color: disp.vfd ? "#07100e" : "#9ebf58" }
        }
    }
    Item {
        id: inner
        anchors.fill: face
        layer.enabled: disp.vfd
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0.435, 0.96, 0.84, 0.75)
            shadowBlur: 0.3
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
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
        opacity: disp.vfd ? 0.05 : 0.2
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
