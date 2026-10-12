// − ● ● ● ○ ○ ○ +  : card widths from Ui.cardMin to Ui.cardMax in steps of Ui.cardStep.
//   CardSizer { onStepped: sound("key") }
import QtQuick
import Carthage

Row {
    id: sizer
    signal stepped()
    readonly property var steps: {
        const out = []
        for (let w = Ui.cardMin; w <= Ui.cardMax; w += Ui.cardStep) out.push(w)
        return out
    }
    // The step nearest the saved width (an older saved size may fall between steps).
    readonly property int index: {
        let best = 0
        for (let i = 1; i < steps.length; i++)
            if (Math.abs(steps[i] - Backend.settings.cardWidth) < Math.abs(steps[best] - Backend.settings.cardWidth)) best = i
        return best
    }
    function go(d) {
        const i = Math.max(0, Math.min(steps.length - 1, index + d))
        if (i === index) return
        Backend.settings.cardWidth = steps[i]
        stepped()
    }
    spacing: Ui.gapM
    Accessible.role: Accessible.Grouping
    Accessible.name: "Card size, step " + (index + 1) + " of " + steps.length
    CButton {
        icon.name: "list-remove-symbolic"
        enabled: sizer.index > 0
        Accessible.name: "Smaller cards"
        onClicked: sizer.go(-1)
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapS
        Repeater {
            model: sizer.steps.length
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: index <= sizer.index ? Backend.theme.accent.accent : Qt.alpha(Backend.theme.p.panelText, 0.18)
                Behavior on color { ColorAnimation { duration: 100 * Backend.motion } }
            }
        }
    }
    CButton {
        icon.name: "list-add-symbolic"
        enabled: sizer.index < sizer.steps.length - 1
        Accessible.name: "Bigger cards"
        onClicked: sizer.go(1)
    }
}
