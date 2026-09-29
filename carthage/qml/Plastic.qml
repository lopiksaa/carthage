// The hardware's plastic: a top-to-bottom gradient with the surface grain over it.
import QtQuick
import Carthage

Rectangle {
    id: plastic

    property color topColor: Backend.theme.p.dockTop
    property color bottomColor: Backend.theme.p.dockBottom

    gradient: Gradient {
        GradientStop { position: 0.0; color: plastic.topColor }
        GradientStop { position: 1.0; color: plastic.bottomColor }
    }
    Image {
        anchors.fill: parent
        source: "image://gc/grain/" + Backend.theme.edition + Backend.theme.texQuery
        fillMode: Image.Tile
        opacity: 0.35
        smooth: false
    }
}
