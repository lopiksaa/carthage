// Pick the games in one of your lists: a search field and your library as a checklist. Ticks
// apply at once (no Save step); Done closes.
//   listGamesPicker.openFor(listId, listName)
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property string listId
    property string listName
    property int stamp: 0  // re-reads the ticks after a change
    function openFor(id, name) {
        listId = id
        listName = name
        search.text = ""
        Backend.searchLibrary.genreList = []
        Backend.searchLibrary.genreExclude = []
        open()
        search.forceActiveFocus()
    }
    onClosed: Backend.searchLibrary.filterText = ""

    maxWidth: 460

    contentItem: Column {
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: "Games in " + dlg.listName

        Column {
            width: parent.width
            spacing: 2
            Text {
                text: "Games in “" + dlg.listName + "”"
                width: parent.width
                elide: Text.ElideRight
                color: dlg.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
            }
            Text {
                text: "Tick the games that belong in it."
                color: dlg.pal.panelTextDim
                font.family: Ui.fontText
                font.pixelSize: Ui.textBody
            }
        }
        QQC2.TextField {
            id: search
            width: parent.width
            height: Ui.controlHeight
            leftPadding: 36
            placeholderText: "Find a game"
            placeholderTextColor: dlg.pal.panelTextDim
            color: dlg.pal.panelText
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            selectByMouse: true
            Accessible.name: "Find a game"
            onTextChanged: Backend.searchLibrary.filterText = text
            Keys.onDownPressed: games.forceActiveFocus()
            background: Rectangle {
                radius: Ui.radiusMedium
                color: dlg.pal.panelHover
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
                CIcon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: "search"
                    color: dlg.pal.panelTextDim
                }
            }
        }
        ListView {
            id: games
            width: parent.width
            height: Math.min(contentHeight, 380)
            clip: true
            model: Backend.searchLibrary
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            QQC2.ScrollBar.vertical: CScrollBar { ink: dlg.pal.panelText }
            WheelAccel { flickable: games; step: 120 }
            delegate: QQC2.AbstractButton {
                id: row
                required property string gameId
                required property string title
                required property string source
                required property int index
                readonly property bool inIt: dlg.stamp >= 0 && Backend.inList(dlg.listId, gameId)
                width: ListView.view.width
                height: 38
                hoverEnabled: true
                focusPolicy: Qt.TabFocus  // a click keeps the typing in the search field
                Accessible.role: Accessible.CheckBox
                Accessible.name: title
                Accessible.checked: inIt
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                onClicked: { Backend.setInList(dlg.listId, gameId, !inIt); dlg.stamp++ }
                background: Rectangle {
                    radius: Ui.radiusSmall
                    color: row.hovered || row.activeFocus ? dlg.pal.panelHover : "transparent"
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
                    Image {
                        id: mark
                        anchors.left: box.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                        source: "image://gc/launcher/" + row.source + "/" + dlg.pal.panelTextDim.toString().replace("#", "")
                    }
                    Text {
                        anchors.left: mark.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.title
                        elide: Text.ElideRight
                        color: dlg.pal.panelText
                        font.family: Ui.fontText
                        font.weight: row.inIt ? Font.Bold : Font.DemiBold
                        font.pixelSize: Ui.textBody
                    }
                }
            }
        }
        Text {
            visible: games.count === 0
            text: "No game called “" + search.text + "” in your library."
            color: dlg.pal.panelTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
        }
        Item {
            width: parent.width
            height: done.height
            CButton {
                id: done
                anchors.right: parent.right
                kind: "primary"
                text: "Done"
                onClicked: dlg.close()
            }
        }
    }
}
