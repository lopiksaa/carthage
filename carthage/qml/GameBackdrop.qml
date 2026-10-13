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
    // false: a picture that isn't the current one goes at once (the game view: no old art while
    // the next loads); true: they cross-fade.
    property bool crossFade: true
    // The current art is up (not an old one, not still loading).
    function clear() {  // at once, no fade
        gone.stop()
        layerA.shown = false; layerB.shown = false
        layerA.src = ""; layerB.src = ""
    }
    readonly property bool current: source !== "" && ((layerA.shown && layerA.src === source) || (layerB.shown && layerB.src === source))

    opacity: level
    visible: opacity > 0.005

    property int front: 0           // the layer showing (or about to show) the current art
    onSourceChanged: {
        const layer = front === 0 ? layerA : layerB
        if (source === "") {  // maybe the next game's art is on its way: wait before letting go
            if (!crossFade) { layerA.shown = false; layerB.shown = false; return }
            gone.restart()
            return
        }
        gone.stop()
        if (layer.src === source) { layer.shown = true; return }
        // Load into the other layer; it takes over once its picture is ready.
        const next = front === 0 ? layerB : layerA
        next.shown = false
        if (!crossFade) layer.shown = false
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
        // In: a fade. Out: a fade too, or at once without cross-fading (set here, not with a
        // Behavior: its `enabled` could still read the old `shown` and fade the old art out).
        opacity: 0
        visible: opacity > 0.005
        onShownChanged: {
            if (shown || bd.crossFade) {
                fadeAnim.to = shown ? 1 : 0
                fadeAnim.restart()
            } else {
                fadeAnim.stop()
                opacity = 0
            }
        }
        NumberAnimation { id: fadeAnim; target: art; property: "opacity"; duration: bd.fadeMs * Backend.motion; easing.type: Easing.InOutCubic }
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
