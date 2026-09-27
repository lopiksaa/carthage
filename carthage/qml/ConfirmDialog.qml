// A confirmation in Carthage's own style, for the few things that can't be undone
// (quitting a game). Cancel is the default, so Enter never quits by accident.
import QtQuick
import Carthage

CDialog {
    id: dlg

    property string title
    property string message
    property string actionText
    property var onConfirm

    function ask(t, m, a, fn) {
        title = t
        message = m
        actionText = a
        onConfirm = fn
        open()
        cancelButton.forceActiveFocus()
    }

    maxWidth: 400

    contentItem: Column {
        spacing: Ui.gapL
        Accessible.role: Accessible.Dialog
        Accessible.name: dlg.title

        Column {
            width: parent.width
            spacing: Ui.gapS
            Text {
                width: parent.width
                text: dlg.title
                color: dlg.pal.panelText
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: dlg.message
                color: dlg.pal.panelTextDim
                font.family: "Nunito"
                font.weight: Font.DemiBold
                font.pixelSize: Ui.textBody
                wrapMode: Text.Wrap
            }
        }
        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            CButton {
                id: cancelButton
                text: "Cancel"
                onClicked: dlg.close()
            }
            CButton {
                kind: "danger"
                text: dlg.actionText
                onClicked: {
                    dlg.close()
                    if (dlg.onConfirm) dlg.onConfirm()
                }
            }
        }
    }
}
