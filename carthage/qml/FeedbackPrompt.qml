// A one-time, bottom-left toast asking for feedback. It never blocks anything: closing it (or
// letting it time out) leaves a short hint saying where Send Feedback lives.
import QtQuick
import Carthage

Item {
    id: prompt

    property Item appRoot
    readonly property var pal: Backend.theme.p
    property bool shown: false
    property bool hinting: false  // after closing: only the "where to find it" line

    function show() {
        hinting = false
        shown = true
        idle.restart()
    }
    function dismiss() {
        hinting = true
        idle.stop()
        hintTimer.restart()
    }
    function send() {
        shown = false
        Backend.openUrl(Backend.feedbackUrl)
    }

    // Not answered within a minute: step aside the same way as closing it.
    Timer { id: idle; interval: 60000; onTriggered: prompt.dismiss() }
    Timer { id: hintTimer; interval: 6000; onTriggered: prompt.shown = false }

    width: Math.min(340, parent ? parent.width - 40 : 340)
    height: content.implicitHeight + 2 * Ui.gapL
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    transform: Translate { x: prompt.shown ? 0 : -24 }
    Behavior on opacity { NumberAnimation { duration: 220 * Backend.motion } }
    Accessible.role: Accessible.AlertMessage
    Accessible.name: hinting ? hint.text : title.text + ". " + body.text

    PanelBackground { anchors.fill: parent; radius: Ui.radiusMedium; shadowOffset: 6; shadowBlur: 20 }

    Column {
        id: content
        x: Ui.gapL
        y: Ui.gapL
        width: parent.width - 2 * Ui.gapL
        spacing: Ui.gapS

        Row {
            visible: !prompt.hinting
            width: parent.width
            spacing: Ui.gapS
            CIcon {
                id: bubble
                anchors.verticalCenter: title.verticalCenter
                width: 18
                height: 18
                source: "dialog-messages-symbolic"
                color: Backend.theme.accent.accent
            }
            Text {
                id: title
                width: parent.width - bubble.width - close.width - 2 * Ui.gapS
                text: "How's Carthage so far?"
                color: prompt.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textBody
                wrapMode: Text.Wrap
            }
            CButton {
                id: close
                width: 28
                height: 28
                kind: "ghost"
                icon.name: "window-close-symbolic"
                Accessible.name: "Close"
                onClicked: prompt.dismiss()
            }
        }
        Text {
            id: body
            visible: !prompt.hinting
            width: parent.width
            text: "Tell me what you like and what's missing. It's a short form."
            color: prompt.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textCaption
            wrapMode: Text.Wrap
        }
        CButton {
            visible: !prompt.hinting
            kind: "primary"
            text: "Send Feedback"
            icon.name: "dialog-messages-symbolic"
            onClicked: prompt.send()
        }
        Text {
            id: hint
            visible: prompt.hinting
            width: parent.width
            text: "You can send feedback any time: Menu → System → Send Feedback."
            color: prompt.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
            wrapMode: Text.Wrap
        }
    }
}
