// A button with a die that tumbles when pressed.
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

    Item {
        id: die
        // On the key's face, on whole pixels, travelling with it (like CButton's label).
        width: btn.big ? 22 : 18
        height: width
        x: Math.round((btn.width - width) / 2)
        y: Math.round((btn.height - height) / 2) + btn.faceShift
        opacity: btn.looksDisabled ? 0.4 : 1
        property real hop: 0
        transform: Translate { y: die.hop }

        Rectangle {  // 2-px outline: the weight of the bold labels beside it
            anchors.fill: parent
            radius: 5
            antialiasing: true
            color: "transparent"
            border.width: 2
            border.color: btn.fg
        }
        readonly property var layouts: [[4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]
        Repeater {
            model: die.layouts[btn.face - 1]
            Rectangle {
                required property int modelData
                readonly property int cell: 4  // pip spacing
                width: 3
                height: 3
                radius: 1.5
                antialiasing: true
                color: btn.fg
                x: (die.width - width) / 2 + ((modelData % 3) - 1) * cell
                y: (die.height - height) / 2 + (Math.floor(modelData / 3) - 1) * cell
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
