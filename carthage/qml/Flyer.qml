// A cartridge in flight between the tray and the dock, positioned by its top-left corner.
import QtQuick
import Carthage

Item {
    id: flyer

    property real cardWidth: 150
    property real motion: 1
    property alias cart: cart
    property real lift: 1 // 0 = on a surface, 1 = held high: drives the shadow
    property real spin: 0

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

    property var onNear      // called at 70 % of a launch (the slot opens its flaps)
    property real flightMs: 370
    // Into the dock (Spec §6): a straight path, eased out, 370 ms + 0.12 ms per pixel up to
    // 480; it scales to the dock's size with no overshoot.
    function launch(tx, ty, tScale, done, near) {
        toX = tx; toY = ty; toScale = tScale; onDone = done; onNear = near
        flightMs = Math.min(480, 370 + 0.12 * Math.hypot(tx - x, ty - y))
        ctrlX = x + (tx - x) * 0.25
        ctrlY = Math.min(y, ty) - height * 0.35
        launchAnim.restart()
    }
    function flyBack(tx, ty, done) {
        toX = tx; toY = ty; toScale = 1; onDone = done
        flightMs = Math.min(480, 370 + 0.12 * Math.hypot(tx - x, ty - y))  // (Spec §6, eased out)
        ctrlX = x + (tx - x) * 0.85
        ctrlY = Math.min(y, ty) - height * 0.45
        backAnim.restart()
    }
    // `shrinkTo` < 1 also shrinks it on the way (e.g. into the header's Library button).
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
        smoothTransform: false // window MSAA smooths the edges; a texture layer would make flyers vanish
        transform: Rotation {
            origin.x: cart.width / 2
            origin.y: cart.height / 2
            angle: flyer.spin
        }
    }

    readonly property var flightCurve: [0.22, 0.9, 0.24, 1, 1, 1]
    SequentialAnimation {
        id: launchAnim
        ParallelAnimation {
            NumberAnimation { target: flyer; property: "x"; to: flyer.toX; duration: flyer.flightMs * flyer.motion; easing.type: Easing.BezierSpline; easing.bezierCurve: flyer.flightCurve }
            NumberAnimation { target: flyer; property: "y"; to: flyer.toY; duration: flyer.flightMs * flyer.motion; easing.type: Easing.BezierSpline; easing.bezierCurve: flyer.flightCurve }
            NumberAnimation { target: flyer; property: "scale"; to: flyer.toScale; duration: flyer.flightMs * flyer.motion; easing.type: Easing.BezierSpline; easing.bezierCurve: flyer.flightCurve }
            NumberAnimation { target: flyer; property: "lift"; to: 0.35; duration: flyer.flightMs * flyer.motion; easing.type: Easing.BezierSpline; easing.bezierCurve: flyer.flightCurve }
            SequentialAnimation {
                PauseAnimation { duration: 0.7 * flyer.flightMs * flyer.motion }
                ScriptAction { script: if (flyer.onNear) flyer.onNear() }
            }
        }
        ScriptAction { script: if (flyer.onDone) flyer.onDone() }
    }

    SequentialAnimation {
        id: backAnim
        ParallelAnimation {
            PathAnimation {
                target: flyer
                duration: flyer.flightMs * flyer.motion
                easing.type: Easing.OutCubic
                path: Path {
                    PathQuad { x: flyer.toX; y: flyer.toY; controlX: flyer.ctrlX; controlY: flyer.ctrlY }
                }
            }
            NumberAnimation { target: flyer; property: "scale"; to: 1; duration: flyer.flightMs * flyer.motion; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: flyer; property: "lift"; to: 1; duration: 0.44 * flyer.flightMs * flyer.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: flyer; property: "lift"; to: 0.1; duration: 0.56 * flyer.flightMs * flyer.motion; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                NumberAnimation { target: flyer; property: "spin"; to: 3; duration: 0.4 * flyer.flightMs * flyer.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: flyer; property: "spin"; to: 0; duration: 0.6 * flyer.flightMs * flyer.motion; easing.type: Easing.InOutQuad }
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
