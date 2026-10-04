// The bar above the tray, lined up with its first and last pockets.
import QtQuick
import Carthage

Item {
    id: bar

    property Item tray
    property Item appRoot
    property string title: "Library"
    property bool withSources: true  // launchers in Show (the sidebar concept lists them itself)
    property bool sourcePage: false  // one launcher's games: no Show menu
    property int count: -1           // shown instead of the library's count (a list page)
    readonly property var pal: Backend.theme.p

    readonly property var showOptions: [
        { value: "all", text: "All" },
        { value: "installed", text: "Installed" },
        { value: "notinstalled", text: "Not Installed" },
    ].concat(withSources && Backend.games.launchers.length > 1 ? Backend.games.launchers : [])
    readonly property var sortOptions: [
        { value: "recent", text: "Recently Played" },
        { value: "playtime", text: "Most Played" },
        { value: "az", text: "Name" },
        { value: "launcher", text: "Launcher" },
        { value: "added", text: "Recently Added" },
    ]

    height: 52
    // Narrow (a small window): the menus show just their value, then the count goes.
    readonly property bool compact: width < 800
    readonly property bool tiny: width < 720

    Row {
        x: bar.tray ? bar.tray.contentLeft : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        EngravedLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.title
        }
        Text {
            visible: !bar.tiny
            anchors.verticalCenter: parent.verticalCenter
            readonly property int n: bar.count >= 0 ? bar.count : Backend.games.count + Backend.favorites.count
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
            visible: !bar.sourcePage
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            compact: bar.compact
            compactIcon: "download"
            label: "Show"
            value: Backend.games.filterMode
            options: bar.showOptions
            onPicked: (v) => Backend.games.filterMode = v
        }
        CDropdown {
            visible: Backend.genreOptions.length > 0  // once the genres have loaded
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            compact: bar.compact
            compactIcon: "tag"
            label: "Genre"
            chipColumns: 3
            value: Backend.games.genre
            options: [{ value: 0, text: "All" }].concat(Backend.genreOptions)
            onPicked: (v) => Backend.games.genre = v
        }
        CDropdown {
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            compact: bar.compact
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
