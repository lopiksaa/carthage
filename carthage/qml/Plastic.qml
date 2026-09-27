// The hardware's molded plastic: lit from above (`topColor` to `bottomColor`), with the grain of the
// surface over it. The header, dock, settings drawer and settings screen are made of it.
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
    readonly property bool metal: Backend.theme.skin === "hifi"
    Image {
        anchors.fill: parent
        // Hi-Fi: brushed aluminum streaks; Plastic: the pebbled grain.
        source: plastic.metal ? "image://gc/brushed" : "image://gc/grain/" + Backend.theme.edition + Backend.theme.texQuery
        fillMode: Image.Tile
        opacity: plastic.metal ? 0.55 : 0.35
        smooth: false
    }
}
