// A cartridge in flight between the tray and the dock. Positioned by its top-left
// corner (transformOrigin TopLeft) so start/end points are simple to compute.
import QtQuick

import Carthage
Item {
    id: flyer

    property real cardWidth: 150
    property real motion: 1
    property alias cart: cart
    property real lift: 1 // 0 = on a surface, 1 = held high: drives the shadow
    property real spin: 0

    // Path target and control point for the current flight.
    property real toX
    property real toY
    property real ctrlX
    property real ctrlY
    property real toScale: 1
    property var onDone
    property real awayScale: 1

    readonly property var pal: Backend.theme.p

    width: cardWidth
    height: cardWidth * Backend.theme.ratio
    transformOrigin: Item.TopLeft

    // Tray → above a free slot. Starts with a small press, then an arc.
    function launch(tx, ty, tScale, done) {
        toX = tx; toY = ty; toScale = tScale; onDone = done
        ctrlX = x + (tx - x) * 0.25
        ctrlY = Math.min(y, ty) - height * 0.35
        launchAnim.restart()
    }
    // Above the slot → back into its recess, arriving from above.
    function flyBack(tx, ty, done) {
        toX = tx; toY = ty; toScale = 1; onDone = done
        ctrlX = x + (tx - x) * 0.85
        ctrlY = Math.min(y, ty) - height * 0.45
        backAnim.restart()
    }
    // The recess is scrolled out of view or filtered away: head toward it and fade.
    // Fade out while heading toward (tx, ty); `shrinkTo` < 1 also shrinks it on the way
    // (e.g. into the header's Library button).
    function flyAway(tx, ty, done, shrinkTo) {
        toX = tx; toY = ty; onDone = done
        awayScale = scale * (shrinkTo === undefined ? 1 : shrinkTo)
        ctrlX = (x + tx) / 2
        ctrlY = Math.min(y, ty) - height * 0.3
        awayAnim.restart()
    }

    Image {
        readonly property real sp: flyer.cardWidth * 0.16
        x: -sp + flyer.cardWidth * (0.02 + 0.09 * flyer.lift)
        y: -sp + flyer.cardWidth * (0.03 + 0.16 * flyer.lift)
        width: flyer.cardWidth + 2 * sp
        height: flyer.height + 2 * sp
        scale: 1 + 0.06 * flyer.lift
        opacity: flyer.pal.shadowStrength * (0.75 - 0.35 * flyer.lift)
        source: "image://gc/shadow/" + Backend.theme.edition
        sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
    }

    Cartridge {
        id: cart
        width: flyer.cardWidth
        smoothTransform: false // window MSAA smooths the edges; a texture layer made flyers vanish
        transform: Rotation {
            origin.x: cart.width / 2
            origin.y: cart.height / 2
            angle: flyer.spin
        }
    }

    SequentialAnimation {
        id: launchAnim
        NumberAnimation { target: flyer; property: "scale"; to: flyer.scale * 0.97; duration: 80 * flyer.motion; easing.type: Easing.OutQuad }
        ParallelAnimation {
            PathAnimation {
                target: flyer
                duration: 370 * flyer.motion
                easing.type: Easing.InOutCubic
                path: Path {
                    PathQuad { x: flyer.toX; y: flyer.toY; controlX: flyer.ctrlX; controlY: flyer.ctrlY }
                }
            }
            NumberAnimation { target: flyer; property: "scale"; to: flyer.toScale; duration: 370 * flyer.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyer; property: "lift"; to: 0.35; duration: 370 * flyer.motion; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                NumberAnimation { target: flyer; property: "spin"; to: -4; duration: 150 * flyer.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: flyer; property: "spin"; to: 0; duration: 220 * flyer.motion; easing.type: Easing.InOutQuad }
            }
        }
        ScriptAction { script: if (flyer.onDone) flyer.onDone() }
    }

    SequentialAnimation {
        id: backAnim
        ParallelAnimation {
            PathAnimation {
                target: flyer
                duration: 450 * flyer.motion
                easing.type: Easing.OutCubic
                path: Path {
                    PathQuad { x: flyer.toX; y: flyer.toY; controlX: flyer.ctrlX; controlY: flyer.ctrlY }
                }
            }
            NumberAnimation { target: flyer; property: "scale"; to: 1; duration: 450 * flyer.motion; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: flyer; property: "lift"; to: 1; duration: 200 * flyer.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: flyer; property: "lift"; to: 0.1; duration: 250 * flyer.motion; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                NumberAnimation { target: flyer; property: "spin"; to: 3; duration: 180 * flyer.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: flyer; property: "spin"; to: 0; duration: 270 * flyer.motion; easing.type: Easing.InOutQuad }
            }
        }
        ScriptAction { script: if (flyer.onDone) flyer.onDone() }
    }

    SequentialAnimation {
        id: awayAnim
        ParallelAnimation {
            PathAnimation {
                target: flyer
                duration: 400 * flyer.motion
                easing.type: Easing.InCubic
                path: Path {
                    PathQuad { x: flyer.toX; y: flyer.toY; controlX: flyer.ctrlX; controlY: flyer.ctrlY }
                }
            }
            NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: 400 * flyer.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: flyer; property: "scale"; to: flyer.awayScale; duration: 400 * flyer.motion; easing.type: Easing.InCubic }
        }
        ScriptAction { script: if (flyer.onDone) flyer.onDone() }
    }
}
