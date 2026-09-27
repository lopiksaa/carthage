// A cartridge carried by the pointer. App.qml decides the drop; `settle` flies it into place.
import QtQuick
import Carthage

Item {
    id: drag

    property alias cart: cart
    property real cardW: 150
    property string hint: ""        // what dropping here does ("" = puts it back)
    property string hintIcon: ""
    property bool overDock: false
    property real motion: 1
    property real grabX: 0.5
    property real grabY: 0.5
    signal settled()

    readonly property real cardH: cardW * Backend.theme.ratio
    width: cardW
    height: cardH

    property real vx: 0
    property double lastT: 0
    function follow(px, py) {
        const nx = px - grabX * cardW
        const ny = py - grabY * cardH
        const now = Date.now()
        const dt = Math.max(1, now - lastT)
        vx = vx * 0.6 + 0.4 * (nx - x) / dt * 16
        lastT = now
        x = nx
        y = ny
        swingReset.restart()
    }
    Timer { id: swingReset; interval: 80; onTriggered: drag.vx = 0 }

    property real swing: Math.max(-9, Math.min(9, -vx * 0.35))
    Behavior on swing { SpringAnimation { spring: 3.5; damping: 0.3; epsilon: 0.05 } }
    property real lift: 1
    scale: (overDock ? 0.86 : 1.05)
    Behavior on scale { NumberAnimation { duration: 140 * drag.motion; easing.type: Easing.OutCubic } }
    transformOrigin: Item.Center

    // Fly to a card's resting place (parent coordinates), then report. `springTo` goes
    // back home as if on a rubber band: quick, a little past, and back.
    function settle(tx, ty, toScale) {
        go(tx, ty, toScale === undefined ? 1 : toScale, Easing.OutCubic, 220)
    }
    function springTo(tx, ty) {
        go(tx, ty, 1, Easing.OutBack, 380)
    }
    function go(tx, ty, ts, easing, ms) {
        settleAnim.tx = tx
        settleAnim.ty = ty
        settleAnim.ts = ts
        settleAnim.easing = easing
        settleAnim.ms = ms
        hint = ""
        vx = 0
        if (motion <= 0) { settled(); return }
        settleAnim.restart()
    }
    ParallelAnimation {
        id: settleAnim
        property real tx
        property real ty
        property real ts: 1
        property int easing: Easing.OutCubic
        property int ms: 220
        NumberAnimation { target: drag; property: "x"; to: settleAnim.tx; duration: settleAnim.ms * drag.motion; easing.type: settleAnim.easing; easing.overshoot: 1.1 }
        NumberAnimation { target: drag; property: "y"; to: settleAnim.ty; duration: settleAnim.ms * drag.motion; easing.type: settleAnim.easing; easing.overshoot: 1.1 }
        NumberAnimation { target: drag; property: "scale"; to: settleAnim.ts; duration: settleAnim.ms * drag.motion; easing.type: Easing.OutCubic }
        NumberAnimation { target: drag; property: "lift"; to: 0; duration: settleAnim.ms * drag.motion; easing.type: Easing.OutCubic }
        onFinished: drag.settled()
    }

    Image {
        readonly property real sp: drag.cardW * 0.16 // must match render.SHADOW_PAD
        x: -sp + drag.cardW * (0.02 + 0.07 * drag.lift)
        y: -sp + drag.cardW * (0.03 + 0.12 * drag.lift)
        width: drag.cardW + 2 * sp
        height: drag.cardH + 2 * sp
        opacity: Backend.theme.p.shadowStrength * (0.7 + 0.3 * drag.lift)
        source: "image://gc/shadow/" + Backend.theme.edition
        sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
        rotation: drag.swing
    }
    Cartridge {
        id: cart
        width: drag.cardW
        smoothTransform: true
        rotation: drag.swing
        transformOrigin: Item.Top
    }

    Rectangle {
        visible: drag.hint !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        readonly property bool above: drag.parent && drag.y + drag.cardH + 60 > drag.parent.height
        y: above ? -height - 14 : drag.cardH + 14
        width: tagRow.implicitWidth + 2 * Ui.gapM
        height: 30
        radius: 15
        color: Backend.theme.accent.accent
        scale: 1 / drag.scale  // the tag keeps its size while the card grows or shrinks
        Row {
            id: tagRow
            anchors.centerIn: parent
            spacing: 6
            CIcon {
                visible: drag.hintIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: drag.hintIcon
                isMask: true
                color: Backend.theme.accent.accentText
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: drag.hint
                color: Backend.theme.accent.accentText
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textCaption
            }
        }
    }
}
