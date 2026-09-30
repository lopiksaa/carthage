// The bar above the tray, lined up with its first and last pockets.
import QtQuick
import Carthage

Item {
    id: bar

    property Item tray
    property Item appRoot
    readonly property var pal: Backend.theme.p

    readonly property var showOptions: [
        { value: "all", text: "All" },
        { value: "installed", text: "Installed" },
        { value: "notinstalled", text: "Not Installed" },
    ].concat(Backend.games.launchers.length > 1 ? Backend.games.launchers : [])
    readonly property var sortOptions: [
        { value: "recent", text: "Recently Played" },
        { value: "playtime", text: "Most Played" },
        { value: "az", text: "Name" },
        { value: "launcher", text: "Launcher" },
        { value: "added", text: "Recently Added" },
    ]

    height: 52

    Row {
        x: bar.tray ? bar.tray.contentLeft : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        EngravedLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "Library"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            readonly property int n: Backend.games.count + Backend.favorites.count
            text: n + " "
                  + (Backend.games.filterText !== "" ? (n === 1 ? "match" : "matches") : (n === 1 ? "game" : "games"))
            color: bar.pal.trayTextDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: bar.tray ? bar.width - bar.tray.contentRight : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapS
        CDropdown {
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            label: "Show"
            value: Backend.games.filterMode
            options: bar.showOptions
            onPicked: (v) => Backend.games.filterMode = v
        }
        CDropdown {
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            label: "Sort"
            value: Backend.games.sortMode
            options: bar.sortOptions
            onPicked: (v) => Backend.games.sortMode = v
        }
        DiceButton {
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            onRolled: bar.appRoot.rollDice()
        }
        CButton {
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            icon.name: "list-add-symbolic"
            Accessible.name: "Add Game"
            onClicked: bar.appRoot.addGame()
        }
    }
}
