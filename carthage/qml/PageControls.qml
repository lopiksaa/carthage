// Over a game's closer look or store page: ← → to the previous / next game at the window's
// sides (the keyboard's arrows do the same) and ✕ in the corner, with the dice beside it
// when `dice` is set.
//   PageControls { anchors.fill: parent; shown: open; arrows: wide; onStep: (d) => step(d); onClose: close() }
import QtQuick
import Carthage

Item {
    id: pc

    property bool shown: false
    property bool arrows: true
    property bool dice: false
    signal step(int dir)
    signal close()
    signal roll()

    Repeater {
        model: [-1, 1]
        CButton {
            required property int modelData
            x: modelData < 0 ? Ui.gapL : pc.width - width - Ui.gapL
            anchors.verticalCenter: parent.verticalCenter
            kind: "scrim"
            icon.name: modelData < 0 ? "go-previous-symbolic" : "go-next-symbolic"
            Accessible.name: modelData < 0 ? "Previous game" : "Next game"
            focusPolicy: Qt.NoFocus
            visible: pc.shown && pc.arrows
            onClicked: pc.step(modelData)
        }
    }
    DiceButton {
        anchors.top: closeButton.top
        anchors.right: closeButton.left
        anchors.rightMargin: Ui.gapS
        kind: "ghost"
        tint: "#ffffff"
        focusPolicy: Qt.NoFocus
        visible: pc.shown && pc.dice
        onRolled: pc.roll()
    }
    CButton {
        id: closeButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        kind: "ghost"
        tint: "#ffffff"
        icon.name: "window-close-symbolic"
        Accessible.name: "Close"
        visible: pc.shown
        onClicked: pc.close()
    }
}
