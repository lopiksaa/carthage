// The glass look's ground: four colour fields in the chosen motion (Settings → Appearance →
// Background: Studio, Light rays, Mesh, Iridescent, Contours or Still), drawn by one shader.
// It responds to what you do: a soft glow follows the pointer, the colours drift a little as the
// library scrolls, and playing or opening a game sends a pulse of light from it (Ui.groundPulse).
// Night (dark hardware): the colours glow; day (light): pastel washes.
// The motion pauses when Carthage isn't the active window, while a game runs (no GPU taken from
// it) and with animations off.
import QtQuick
import Carthage

Item {
    id: bd

    property bool interactive: true      // the Settings preview turns this off
    property string variantName: Backend.settings.background || "studio"
    readonly property var g: Backend.theme.glass
    // (older names fall back to Studio)
    readonly property int variant: ({ still: 0, studio: 1, rays: 2, mesh: 3, iris: 4, topo: 5 })[variantName] ?? 1
    readonly property bool moving: variant !== 0 && Backend.motion > 0
                                   && (Qt.application.state === Qt.ApplicationActive || Backend.testNoFocus)  // (test windows never take focus)
                                   && Backend.sessions.count === 0
    property real time: 37   // (not 0: the first frame already looks like a moment in the motion)

    // 30 steps a second: the motion is slow enough to look smooth, and the window doesn't
    // redraw at the screen's full rate just for the ground (the pointer and everything you do
    // still draw at full rate).
    Timer {
        interval: 33
        repeat: true
        running: bd.moving && bd.visible
        onTriggered: bd.time += 0.033 * Backend.motion
    }

    function v4(c) { const q = Qt.color(c); return Qt.vector4d(q.r, q.g, q.b, q.a) }

    // The pointer's glow follows lazily; it fades in over the window and out when it leaves.
    property real px: 0.5
    property real py: 0.5
    property real pIn: 0
    Behavior on px { enabled: Backend.motion > 0; SmoothedAnimation { velocity: 0.6 } }
    Behavior on py { enabled: Backend.motion > 0; SmoothedAnimation { velocity: 0.6 } }
    Behavior on pIn { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Binding on px { when: bd.interactive && bd.width > 0; value: Ui.groundPointer.x / bd.width }
    Binding on py { when: bd.interactive && bd.height > 0; value: Ui.groundPointer.y / bd.height }
    Binding on pIn { when: bd.interactive; value: Ui.groundPointerIn && Backend.motion > 0 ? 1 : 0 }

    // A pulse: a ring of light spreading from a point.
    property real pulseX: 0.5
    property real pulseY: 0.5
    property real pulseT: 1
    NumberAnimation {
        id: pulseAnim
        target: bd
        property: "pulseT"
        from: 0
        to: 1
        duration: 1400
        easing.type: Easing.OutCubic
    }
    Connections {
        target: Ui
        enabled: bd.interactive
        function onGroundPulse(x, y) {
            if (Backend.motion <= 0 || bd.width <= 0) return
            bd.pulseX = x / bd.width
            bd.pulseY = y / bd.height
            pulseAnim.restart()
        }
    }

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/backdrop.frag.qsb")
        property real time: bd.time
        property real variant: bd.variant
        property real aspect: bd.width / Math.max(1, bd.height)
        property real dark: Backend.theme.dark ? 1 : 0
        property vector4d bg: bd.v4(bd.g.bg)
        property vector4d c0: bd.v4(bd.g.fields[0])
        property vector4d c1: bd.v4(bd.g.fields[1])
        property vector4d c2: bd.v4(bd.g.fields[2])
        property vector4d c3: bd.v4(bd.g.fields[3])
        property vector4d p0: Qt.vector4d(bd.g.centres[0][0], bd.g.centres[0][1], bd.g.centres[0][2], bd.g.centres[0][3])
        property vector4d p1: Qt.vector4d(bd.g.centres[1][0], bd.g.centres[1][1], bd.g.centres[1][2], bd.g.centres[1][3])
        property vector4d p2: Qt.vector4d(bd.g.centres[2][0], bd.g.centres[2][1], bd.g.centres[2][2], bd.g.centres[2][3])
        property vector4d p3: Qt.vector4d(bd.g.centres[3][0], bd.g.centres[3][1], bd.g.centres[3][2], bd.g.centres[3][3])
        property vector4d pointer: Qt.vector4d(bd.px, bd.py, bd.pIn, 0)
        property vector4d pulse: Qt.vector4d(bd.pulseX, bd.pulseY, bd.pulseT, bd.pulseT < 1 ? 1 : 0)
        property vector4d accent: bd.v4(bd.g.accent)
        property real scroll: bd.interactive ? Ui.groundScroll : 0
    }
}
