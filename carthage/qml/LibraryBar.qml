// The bar above the tray, lined up with its first and last pockets.
import QtQuick
import Carthage

Item {
    id: bar

    property Item tray
    property Item appRoot
    readonly property var pal: Backend.theme.p
    readonly property bool hifi: Backend.theme.skin === "hifi"

    readonly property var showOptions: [
        { value: "all", text: "All" },
        { value: "installed", text: "Installed", short: "Ready" },
        { value: "notinstalled", text: "Not Installed", short: "Get" },
    ].concat(Backend.games.launchers.length > 1 ? Backend.games.launchers : [])
    readonly property var sortOptions: [
        { value: "recent", text: "Recently Played", short: "Recent" },
        { value: "playtime", text: "Most Played", short: "Played" },
        { value: "az", text: "Name" },
        { value: "launcher", text: "Launcher" },
        { value: "added", text: "Recently Added", short: "Added" },
    ]

    height: hifi ? 64 : 52

    Plastic {
        visible: bar.hifi
        anchors.fill: parent
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: bar.pal.dockHi }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: bar.pal.dockSeam }
    }

    Row {
        id: leftRow
        x: bar.tray ? bar.tray.contentLeft : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        EngravedLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "Library"
            onMetal: bar.hifi
        }
        readonly property int n: Backend.games.count + Backend.favorites.count
        Display {
            id: countDisplay
            visible: !bare
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(34, countText.implicitWidth + 14)
            height: 24
            Text {
                id: countText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: countDisplay.vfd ? 1 : 0
                text: String(leftRow.n)
                color: countDisplay.ink
                font.family: countDisplay.fontFamily
                font.pixelSize: countDisplay.fontPx(14)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            readonly property int n: Backend.games.count + Backend.favorites.count
            text: (countDisplay.bare ? n + " " : "")
                  + (Backend.games.filterText !== "" ? (n === 1 ? "match" : "matches") : (n === 1 ? "game" : "games"))
            color: bar.hifi ? bar.pal.dockTextDim : bar.pal.trayTextDim
            font.family: bar.hifi ? "Barlow Condensed" : "Nunito"
            font.weight: Font.Bold
            font.pixelSize: bar.hifi ? 12 : Ui.textCaption
            font.letterSpacing: bar.hifi ? 2 : 0
            font.capitalization: bar.hifi ? Font.AllUppercase : Font.MixedCase
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: bar.tray ? bar.width - bar.tray.contentRight : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: bar.hifi ? Ui.gapL : Ui.gapS
        CDropdown {
            visible: !bar.hifi
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            label: "Show"
            value: Backend.games.filterMode
            options: bar.showOptions
            onPicked: (v) => Backend.games.filterMode = v
        }
        CDropdown {
            visible: !bar.hifi
            anchors.verticalCenter: parent.verticalCenter
            kind: "key"
            label: "Sort"
            value: Backend.games.sortMode
            options: bar.sortOptions
            onPicked: (v) => Backend.games.sortMode = v
        }
        TapeKeys {
            visible: bar.hifi
            anchors.verticalCenter: parent.verticalCenter
            appRoot: bar.appRoot
            options: bar.showOptions
            value: Backend.games.filterMode
            onPicked: (v) => Backend.games.filterMode = v
            Accessible.name: "Show"
        }
        RotarySelector {
            visible: bar.hifi
            anchors.verticalCenter: parent.verticalCenter
            appRoot: bar.appRoot
            options: bar.sortOptions
            value: Backend.games.sortMode
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
