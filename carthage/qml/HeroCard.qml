// The cartridge you hold in a game's closer look (Inspect.qml), also used by the first-run
// splash: the real 3D card (Card3D) with its shadow; it tilts toward the pointer, spins when
// dragged and flips when clicked, and drifts faintly while left alone. `amp` adds a gentle
// float (the splash) and jump() a little hop.
// Inspect.qml runs its own spin animations (selfSettling: false) and answers tapped/released;
// on its own it settles face or back after a drag and flips on a click.
//   HeroCard { width: 200; game: ({ gameId: …, source: …, … }); holding: true }
import QtQuick
import QtQuick.Effects
import Carthage

Item {
    id: hero

    property var game: ({})
    property real motion: Backend.motion
    property bool holding: true          // it can be tilted, dragged and clicked
    property bool busy: false            // an outside animation runs (no idle drift meanwhile)
    property bool selfSettling: true
    property real amp: 0                 // the gentle float, in px (0: only the faint drift)
    signal tapped()
    signal released(real velocityX)

    height: width * Backend.theme.ratio

    property real spin: 0 // degrees around the vertical axis; 180 shows the back
    property real dragTilt: 0 // forward/back tip while being dragged
    property real press: 1
    readonly property bool showingBack: Math.cos(spin * Math.PI / 180) < 0
    readonly property bool dragging: spinDrag.active
    readonly property bool hovered: heroHover.hovered
    readonly property bool tilting: heroHover.hovered && !spinDrag.active && holding
                                    && Backend.settings.tiltEnabled && motion > 0
    readonly property bool idle: holding && !busy && !spinDrag.active && !heroHover.hovered
                                 && !ownFlip.running && !ownSettle.running
    // The pointer presses the card where it is: that part tips away, the opposite side comes up.
    property real tiltX: tilting ? (heroHover.point.position.y / height - 0.5) * 2 * 7 : 0
    property real tiltY: tilting ? (heroHover.point.position.x / width - 0.5) * 2 * 7 : 0
    Behavior on tiltX { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }
    Behavior on tiltY { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }

    IdleDrift {
        id: drift
        active: hero.idle
        motion: hero.motion
    }
    // The float (amp) and the hop, up and down only.
    property real floatY: 0
    property real jumpY: 0
    readonly property real lift: floatY + jumpY
    SequentialAnimation on floatY {
        loops: Animation.Infinite
        running: hero.amp > 0 && hero.visible && hero.motion > 0
        NumberAnimation { to: -hero.amp; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { to: hero.amp; duration: 1500; easing.type: Easing.InOutSine }
    }
    function jump() { if (motion > 0) hop.restart() }
    SequentialAnimation {
        id: hop
        NumberAnimation { target: hero; property: "jumpY"; to: -14; duration: 110 * hero.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: hero; property: "jumpY"; to: 0; duration: 320 * hero.motion; easing.type: Easing.OutBounce }
    }

    // Larger than the card, so the corners have room while it turns.
    Card3D {
        id: card3d
        visible: false  // (drawn by the shadow effect below, with its shadow)
        anchors.centerIn: parent
        width: hero.width * 2.1
        height: hero.height * 1.35
        cardHeight: hero.height
        game: hero.game
        anchors.verticalCenterOffset: drift.float + hero.lift
        spin: hero.spin + drift.turn
        tiltX: hero.tiltX + hero.dragTilt + drift.tip
        tiltY: hero.tiltY
        scale: hero.press
    }

    // The shadow is the card's own outline as you see it (the 3D view is transparent around it),
    // dropped down-right from the top-left light and blurred: it turns, tips and narrows exactly
    // as the card does. Floating higher puts it further away and fainter.
    MultiEffect {
        readonly property real up: hero.amp > 0 ? Math.max(0, -hero.lift) / (2 * hero.amp) : 0
        anchors.fill: card3d
        source: card3d
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: Backend.theme.p.shadowStrength * 0.85 * (1 - 0.3 * up)
        shadowBlur: 0.7 + 0.2 * up
        blurMax: 48
        shadowHorizontalOffset: hero.width * (0.04 + 0.04 * up)
        shadowVerticalOffset: hero.width * (0.07 + 0.06 * up)
        shadowScale: 1.0
    }

    HoverHandler {
        id: heroHover
        cursorShape: spinDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }
    DragHandler {
        id: spinDrag
        target: null
        enabled: hero.holding
        property real startSpin: 0
        onActiveChanged: {
            if (active) {
                ownFlip.stop()
                ownSettle.stop()
                startSpin = hero.spin
            } else {
                hero.released(centroid.velocity.x)
                if (hero.selfSettling) hero.settle(centroid.velocity.x)
            }
        }
        onTranslationChanged: {
            if (!active) return
            hero.spin = startSpin + translation.x * 0.55
            hero.dragTilt = Math.max(-30, Math.min(30, -translation.y * 0.25))
        }
    }
    TapHandler {
        enabled: hero.holding
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            hero.tapped()
            if (hero.selfSettling) hero.flip()
        }
    }

    // On its own (selfSettling): after a drag it coasts to the nearest face or back; a click flips it.
    function settle(velocityX) {
        const coast = spin + Math.max(-540, Math.min(540, velocityX * 0.25))
        ownSettle.spinTo = Math.round(coast / 180) * 180
        if (motion <= 0) { spin = ownSettle.spinTo; dragTilt = 0; return }
        ownSettle.restart()
    }
    function flip() {
        const target = Math.round(spin / 180) * 180 + 180
        if (motion <= 0) { spin = target % 360; return }
        ownFlip.to = target
        ownFlip.restart()
    }
    ParallelAnimation {
        id: ownSettle
        property real spinTo: 0
        NumberAnimation {
            target: hero
            property: "spin"
            to: ownSettle.spinTo
            duration: Math.min(900, 260 + Math.abs(ownSettle.spinTo - hero.spin) * 1.1) * hero.motion
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
        NumberAnimation { target: hero; property: "dragTilt"; to: 0; duration: 380 * hero.motion; easing.type: Easing.OutBack }
        onFinished: hero.spin = ((hero.spin % 360) + 360) % 360
    }
    NumberAnimation {
        id: ownFlip
        target: hero
        property: "spin"
        duration: 460 * hero.motion
        easing.type: Easing.OutBack
        easing.overshoot: 0.8
        onFinished: hero.spin = hero.spin % 360
    }
}
