// Add a game to your lists: one row per list (a tick when the game is in it), and a new list.
//   listPicker.openFor(gameId, title)
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property Item appRoot
    property string gameId
    property string gameTitle
    property int stamp: 0  // re-reads the ticks after a change
    function openFor(gid, title) {
        gameId = gid
        gameTitle = title || ""
        open()
    }

    maxWidth: 380

    contentItem: Column {
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: "Add " + dlg.gameTitle + " to a list"

        Column {
            width: parent.width
            spacing: 2
            Text {
                text: "Add to List"
                color: dlg.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
            }
            Text {
                width: parent.width
                text: dlg.gameTitle
                color: dlg.pal.panelTextDim
                font.family: Ui.fontText
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
        }
        // No lists yet: say so, and make a new one the obvious next step.
        Text {
            visible: Backend.lists.length === 0
            width: parent.width
            text: "You don't have any lists yet. Make one, and this game goes straight in."
            wrapMode: Text.Wrap
            color: dlg.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
        }
        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: Backend.lists
                delegate: QQC2.AbstractButton {
                    id: row
                    required property var modelData
                    readonly property bool inIt: dlg.stamp >= 0 && Backend.inList(modelData.id, dlg.gameId)
                    width: parent.width
                    height: 40
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: modelData.name
                    Accessible.checked: inIt
                    Keys.onReturnPressed: clicked()
                    onClicked: { Backend.setInList(modelData.id, dlg.gameId, !inIt); dlg.stamp++ }
                    background: Rectangle {
                        radius: Ui.radiusSmall
                        color: row.hovered ? dlg.pal.panelHover : "transparent"
                        border.width: row.visualFocus ? 2 : 0
                        border.color: Ui.focusColor
                    }
                    contentItem: Item {
                        Rectangle {  // the tick box
                            id: box
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 5
                            color: row.inIt ? Backend.theme.accent.accent : "transparent"
                            border.width: row.inIt ? 0 : 1.5
                            border.color: dlg.pal.panelTextDim
                            CIcon {
                                visible: row.inIt
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "checkmark"
                                color: Backend.theme.accent.accentText
                            }
                        }
                        Text {
                            anchors.left: box.right
                            anchors.leftMargin: 12
                            anchors.right: countText.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: dlg.pal.panelText
                            font.family: Ui.fontText
                            font.weight: Font.DemiBold
                            font.pixelSize: Ui.textBody
                        }
                        Text {
                            id: countText
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.count
                            color: dlg.pal.panelTextDim
                            font.family: Ui.fontText
                            font.pixelSize: Ui.textCaption
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: done.height
            readonly property bool none: Backend.lists.length === 0
            CButton {
                visible: !parent.none
                text: "New List…"
                icon.name: "list-add-symbolic"
                onClicked: dlg.appRoot.newList(dlg.gameId)
            }
            Row {
                anchors.right: parent.right
                spacing: Ui.gapM
                CButton {
                    visible: parent.parent.none
                    text: "Cancel"
                    onClicked: dlg.close()
                }
                CButton {
                    id: done
                    kind: "primary"
                    text: parent.parent.none ? "New List…" : "Done"
                    onClicked: parent.parent.none ? dlg.appRoot.newList(dlg.gameId) : dlg.close()
                }
            }
        }
    }
}
