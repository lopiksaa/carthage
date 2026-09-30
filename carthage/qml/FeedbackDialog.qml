// Send Feedback: a text box that posts to the feedback form (Backend.sendFeedback). The text
// stays if the dialog is closed by accident; it's cleared once sent.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property Item appRoot
    property alias text: box.text
    property alias wantsAnswer: answer.checked
    property alias emailText: emailField.text
    property string state_: "writing" // writing | sending | failed
    // With "I want an answer", an address that looks like one (something@something.something).
    readonly property string email: answer.checked ? emailField.text.trim() : ""
    readonly property bool emailOk: !answer.checked || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    readonly property bool canSend: box.text.trim() !== "" && emailOk && state_ !== "sending"

    function start() {
        if (state_ === "failed") state_ = "writing"
        open()
        box.forceActiveFocus()
    }
    function send() {
        if (!canSend) return
        state_ = "sending"
        Backend.sendFeedback(box.text, email)
    }

    Connections {
        target: Backend
        function onFeedbackSent(ok) {
            if (dlg.state_ !== "sending") return
            if (ok) {
                dlg.state_ = "writing"
                box.text = ""
                answer.checked = false
                emailField.text = ""
                dlg.close()
                dlg.appRoot.notify("Thanks! Your feedback was sent.")
            } else {
                dlg.state_ = "failed"
            }
        }
    }

    maxWidth: 480

    contentItem: Column {
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: title.text

        Text {
            id: title
            text: "Send Feedback"
            color: dlg.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }
        Text {
            width: parent.width
            text: "What do you like? What's missing or not working?"
            color: dlg.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        QQC2.ScrollView {
            width: parent.width
            height: 170
            QQC2.ScrollBar.vertical: CScrollBar {}
            QQC2.TextArea {
                id: box
                wrapMode: TextEdit.Wrap
                placeholderText: "Your feedback…"
                placeholderTextColor: dlg.pal.panelTextDim
                color: dlg.pal.panelText
                font.family: Ui.fontText
                font.pixelSize: Ui.textBody
                selectByMouse: true
                leftPadding: 12
                rightPadding: 12
                topPadding: 10
                bottomPadding: 10
                enabled: dlg.state_ !== "sending"
                Accessible.name: "Your feedback"
                Keys.onPressed: (e) => {
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) {
                        dlg.send()
                        e.accepted = true
                    }
                }
                background: Rectangle {
                    radius: Ui.radiusMedium
                    color: dlg.pal.panelHover
                    border.width: box.activeFocus ? 2 : 1
                    border.color: box.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
                }
            }
        }
        CCheckBox {
            id: answer
            text: "I want an answer"
            enabled: dlg.state_ !== "sending"
            onToggled: if (checked) emailField.forceActiveFocus()
        }
        QQC2.TextField {
            id: emailField
            visible: answer.checked
            width: parent.width
            height: Ui.controlHeight
            leftPadding: 12
            rightPadding: 12
            placeholderText: "Your email address"
            placeholderTextColor: dlg.pal.panelTextDim
            color: dlg.pal.panelText
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            inputMethodHints: Qt.ImhEmailCharactersOnly
            selectByMouse: true
            enabled: dlg.state_ !== "sending"
            Accessible.name: "Your email address"
            onAccepted: dlg.send()
            background: Rectangle {
                radius: Ui.radiusMedium
                color: dlg.pal.panelHover
                border.width: emailField.activeFocus ? 2 : 1
                border.color: emailField.text !== "" && !dlg.emailOk ? dlg.pal.dangerText
                            : emailField.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
            }
        }
        Text {
            width: parent.width
            text: dlg.state_ === "failed"
                  ? "Couldn't send it. Check your connection and try again, or send it from your browser."
                  : "Sent to lopiksa with Carthage's version and your operating system"
                    + (answer.checked ? ", and your email so lopiksa can answer. " : ". ") + "Nothing else."
            color: dlg.state_ === "failed" ? dlg.pal.dangerText : dlg.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textCaption
            wrapMode: Text.Wrap
        }
        Item {
            width: parent.width
            height: actions.height
            CButton {
                visible: dlg.state_ === "failed"
                anchors.left: parent.left
                text: "Open in Browser"
                onClicked: {
                    Backend.openUrl(Backend.feedbackFormUrl(box.text, dlg.email))
                    dlg.state_ = "writing"
                    dlg.close()
                }
            }
            Row {
                id: actions
                anchors.right: parent.right
                spacing: Ui.gapM
                CButton {
                    text: "Cancel"
                    onClicked: dlg.close()
                }
                CButton {
                    kind: "primary"
                    text: dlg.state_ === "sending" ? "Sending…" : dlg.state_ === "failed" ? "Try Again" : "Send"
                    enabled: dlg.canSend
                    onClicked: dlg.send()
                }
            }
        }
    }
}
