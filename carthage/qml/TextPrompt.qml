// A small one-field prompt in Carthage's style (used for Rename…).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property string title
    property string hint
    property string actionText: "Save"
    property string secondaryText: ""
    property var onAccept
    property var onSecondary

    function ask(t, h, value, action, fn, secondary, secondaryFn) {
        title = t
        hint = h
        actionText = action
        onAccept = fn
        secondaryText = secondary || ""
        onSecondary = secondaryFn
        field.text = value
        open()
        field.forceActiveFocus()
        field.selectAll()
    }
    function accept() {
        const v = field.text
        close()
        if (onAccept) onAccept(v)
    }

    maxWidth: 420

    contentItem: Column {
        spacing: Ui.gapM
        Text {
            text: dlg.title
            color: dlg.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }
        Text {
            visible: dlg.hint !== ""
            width: parent.width
            text: dlg.hint
            color: dlg.pal.panelTextDim
            font.family: "Nunito"
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        QQC2.TextField {
            id: field
            width: parent.width
            height: Ui.controlHeight
            leftPadding: 12
            rightPadding: 12
            color: dlg.pal.panelText
            font.family: "Nunito"
            font.weight: Font.DemiBold
            font.pixelSize: Ui.textLead
            selectByMouse: true
            onAccepted: dlg.accept()
            background: Rectangle {
                radius: Ui.radiusMedium
                color: dlg.pal.panelHover
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
            }
        }
        // Cancel and the action on the right; a secondary choice (e.g. Original Name) on
        // the left, apart from them.
        Item {
            width: parent.width
            height: actions.height
            CButton {
                visible: dlg.secondaryText !== ""
                anchors.left: parent.left
                text: dlg.secondaryText
                onClicked: {
                    dlg.close()
                    if (dlg.onSecondary) dlg.onSecondary()
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
                    text: dlg.actionText
                    onClicked: dlg.accept()
                }
            }
        }
    }
}
