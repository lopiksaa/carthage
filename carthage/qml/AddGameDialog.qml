// "Add Game…": any program or command as a game, for things no launcher knows about.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

CDialog {
    id: dlg

    property Item appRoot
    property string error: ""

    function start() {
        nameField.text = ""
        commandField.text = ""
        error = ""
        open()
        nameField.forceActiveFocus()
    }
    function submit() {
        error = Backend.addGame(nameField.text, commandField.text)
        if (!error) {
            const n = nameField.text.trim()
            close()
            appRoot.notify(n + " added")
        }
    }


    component Field: QQC2.TextField {
        height: Ui.controlHeight
        leftPadding: 12
        rightPadding: 12
        color: dlg.pal.panelText
        placeholderTextColor: dlg.pal.panelTextDim
        font.family: Ui.fontText
        font.weight: Font.DemiBold
        font.pixelSize: Ui.textBody
        selectByMouse: true
        background: Rectangle {
            radius: Ui.radiusMedium
            color: dlg.pal.panelHover
            border.width: parent.activeFocus ? 2 : 1
            border.color: parent.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
        }
    }
    component Label_: Text {
        color: dlg.pal.panelText
        font.family: Ui.fontText
        font.weight: Font.Bold
        font.pixelSize: Ui.textBody
    }

    contentItem: Column {
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: "Add a game"

        Text {
            text: "Add a Game"
            color: dlg.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }
        Text {
            width: parent.width
            text: "For games no launcher knows about. Steam, Heroic, Lutris and installed apps show up on their own."
            color: dlg.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }

        Label_ { text: "Name"; topPadding: 4 }
        Field {
            id: nameField
            width: parent.width
            placeholderText: "e.g. Minecraft"
            Accessible.name: "Name"
            onAccepted: commandField.forceActiveFocus()
        }

        Label_ { text: "Program or command" }
        Row {
            width: parent.width
            spacing: Ui.gapS
            Field {
                id: commandField
                width: parent.width - browse.width - 8
                placeholderText: "Choose a program, or type a command"
                Accessible.name: "Program or command"
                onAccepted: dlg.submit()
            }
            CButton {
                id: browse
                height: Ui.controlHeight
                text: "Browse…"
                onClicked: picker.open()
            }
        }

        Text {
            visible: dlg.error !== ""
            width: parent.width
            text: dlg.error
            color: dlg.pal.dangerText
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            topPadding: 6
            CButton {
                text: "Cancel"
                onClicked: dlg.close()
            }
            CButton {
                kind: "primary"
                text: "Add Game"
                onClicked: dlg.submit()
            }
        }
    }

    FileDialog {
        id: picker
        title: "Choose the game's program"
        onAccepted: {
            const path = Backend.localPath(selectedFile)
            commandField.text = '"' + path.replace(/"/g, '\\"') + '"'
            if (!nameField.text) {
                const base = path.split(/[\\/]/).pop().replace(/\.(sh|x86_64|AppImage|exe|bin)$/i, "")
                nameField.text = base.replace(/[_-]+/g, " ")
            }
        }
    }
}
