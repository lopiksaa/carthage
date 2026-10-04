// The game's wide art behind the closer look and the store page. The picture itself fades out
// towards the bottom (a gradient mask), so it melts into what's below with no edge. Two layers
// cross-fade: a new game's art fades in over the old one, and when the art goes away (closing,
// rolling the dice) the last picture fades out instead of vanishing. The views keep their dark
// scrim on top, so the text stays readable.
import QtQuick
import QtQuick.Effects
import Carthage

Item {
    id: bd
    property string source
    property real level: 1          // the view's own fade (opening, closing, gallery)
    readonly property int fadeMs: 380

    opacity: level
    visible: opacity > 0.005

    property int front: 0           // the layer showing (or about to show) the current art
    onSourceChanged: {
        const layer = front === 0 ? layerA : layerB
        if (source === "") {  // maybe the next game's art is on its way: wait before letting go
            gone.restart()
            return
        }
        gone.stop()
        if (layer.src === source) { layer.shown = true; return }
        // Load into the other layer; it takes over once its picture is ready.
        const next = front === 0 ? layerB : layerA
        next.shown = false
        next.src = source
        front = front === 0 ? 1 : 0
        if (next.ready) next.takeOver()
    }

    Timer {
        id: gone
        interval: 500
        onTriggered: if (bd.source === "") { layerA.shown = false; layerB.shown = false }
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

    component ArtLayer: Item {
        id: art
        property string src
        property bool shown: false
        readonly property bool ready: img.status === Image.Ready
        function takeOver() {
            shown = true
            const other = art === layerA ? layerB : layerA
            other.shown = false
        }
        anchors.fill: parent
        opacity: shown ? 1 : 0
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: bd.fadeMs * Backend.motion; easing.type: Easing.InOutCubic } }
        Image {
            id: img
            anchors.fill: parent
            source: art.src
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            asynchronous: true
            cache: true
            sourceSize.width: 1600
            visible: false
            onStatusChanged: if (status === Image.Ready && art.src === bd.source) art.takeOver()
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            visible: art.ready
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }
    ArtLayer { id: layerA }
    ArtLayer { id: layerB }
}
