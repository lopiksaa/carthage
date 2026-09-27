// A die on a button: pick a random game (App.rollDice). Pressed, the die is thrown: it hops,
// tumbles two turns and a bit with its faces flickering past, and bounces to rest on one.
//   DiceButton { onRolled: appRoot.rollDice() }
import QtQuick
import Carthage

CButton {
    id: btn

    signal rolled()
    property int face: 5

    Accessible.name: "Pick a random game"
    onClicked: {
        tumble()
        rolled()
    }

    function tumble() {
        if (Backend.motion <= 0) {
            face = 1 + Math.floor(Math.random() * 6)
            return
        }
        spin.to = Math.round(die.rotation / 90) * 90 + 720 + 90 * (1 + Math.floor(Math.random() * 3))
        throwAnim.restart()
        flicker.n = 0
        flicker.interval = 45
        flicker.restart()
    }

    // The die, drawn in the button's ink: a rounded face with its pips.
    Item {
        id: die
        anchors.centerIn: parent
        width: btn.big ? 20 : 16
        height: width
        property real hop: 0
        transform: Translate { y: die.hop }

        Rectangle {
            anchors.fill: parent
            radius: width * 0.24
            antialiasing: true
            color: "transparent"
            border.width: 1.5
            border.color: btn.fg
        }
        // Pips on a 3 × 3 grid (0–8, row by row), per face.
        readonly property var layouts: [[4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]
        Repeater {
            model: die.layouts[btn.face - 1]
            Rectangle {
                required property int modelData
                readonly property real cell: die.width * 0.26
                width: die.width * 0.18
                height: width
                radius: width / 2
                antialiasing: true
                color: btn.fg
                x: die.width / 2 + ((modelData % 3) - 1) * cell - width / 2
                y: die.height / 2 + (Math.floor(modelData / 3) - 1) * cell - height / 2
            }
        }
    }

    SequentialAnimation {
        id: throwAnim
        ParallelAnimation {
            NumberAnimation { id: spin; target: die; property: "rotation"; duration: 620 * Backend.motion; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: die; property: "hop"; to: -7; duration: 130 * Backend.motion; easing.type: Easing.OutQuad }
                NumberAnimation { target: die; property: "hop"; to: 0; duration: 420 * Backend.motion; easing.type: Easing.OutBounce }
            }
        }
        ScriptAction { script: die.rotation = die.rotation % 360 }
    }
    // The faces flicker past while it tumbles, slowing with it.
    Timer {
        id: flicker
        property int n: 0
        interval: 45
        repeat: true
        onTriggered: {
            let f = btn.face
            while (f === btn.face) f = 1 + Math.floor(Math.random() * 6)
            btn.face = f
            interval += 12
            if (++n >= 9) stop()
        }
    }
}
