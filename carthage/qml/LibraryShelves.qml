// The shelves above the library's games: Play Next, then Favorites, then the "All Games"
// title. The tray's header (Tray.qml); `shelf` and `dropZone` are the favorites shelf's (or
// null while that shelf is off), for dragging cartridges onto it.
import QtQuick
import Carthage

Column {
    id: ls

    property Item tray
    property Item appRoot
    readonly property bool favoritesOn: Backend.settings.favoritesShelf
    readonly property var shelf: favoritesOn ? favorites.shelf : null
    readonly property Item dropZone: favoritesOn ? favorites.dropZone : null

    PlayNextShelf {
        id: playNext
        width: ls.width
        tray: ls.tray
        appRoot: ls.appRoot
    }
    FavoritesShelf {
        id: favorites
        width: ls.width
        visible: ls.favoritesOn && showable
        tray: ls.tray
        appRoot: ls.appRoot
    }
    // Always there while a shelf is, so the layout never shifts under a carried cartridge.
    Item {
        visible: playNext.visible || favorites.visible
        width: ls.width
        height: visible ? allGames.height + Ui.gapL : 0
        EngravedLabel {
            id: allGames
            x: ls.tray.contentLeft - ls.tray.leftMargin
            y: Ui.gapL
            text: "All Games"
        }
    }
}
