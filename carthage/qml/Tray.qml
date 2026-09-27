// The carrying-case tray: a grid of recesses holding the cartridges. The same component,
// with `shelf: true`, is the favorites shelf above it: one row of recesses that scrolls
// sideways. A cartridge sits in one or the other, never both (library.py TrayModel).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

GridView {
    id: grid

    property Item appRoot
    property real bottomClearance: 0 // room for cartridges sticking out of the dock
    property var trayModel: Backend.games
    property bool shelf: false
    property Item mainTray: grid     // the shelf hands its card menu to the main tray
    // Where the first column's pocket starts and the last one's ends (for aligning the
    // library bar and the shelf with the grid).
    readonly property real pocketW: cardW + 2 * pad
    readonly property real contentLeft: leftMargin + Math.round((cellWidth - pocketW) / 2)
    readonly property real contentRight: width - rightMargin - Math.round((cellWidth - pocketW) / 2)
    // The favorites shelf in the header (main tray only).
    readonly property var shelfItem: !shelf && headerItem ? headerItem.shelf : null

    readonly property real cardW: Backend.settings.cardWidth
    readonly property real pad: cardW * 0.035
    readonly property real minCell: cardW + 2 * pad + Ui.spacingLarge * 3
    readonly property int columns: Math.max(1, Math.floor((width - leftMargin - rightMargin) / minCell))
    readonly property real titleHeight: Backend.settings.showTitles
        ? Ui.spacingSmall * 2 + fontMetrics.height * 2 + Ui.spacingSmall
        : 0

    function cellFor(gameId) {
        const row = trayModel.rowOf(gameId)
        if (row >= 0) return itemAtIndex(row)
        return shelfItem ? shelfItem.cellFor(gameId) : null
    }
    function cellAt(index) {
        return itemAtIndex(index)
    }
    // True if the cell's card is inside the visible part of the tray.
    function isCellVisible(cell) {
        if (!cell) return false
        const p = cell.mapToItem(grid, cell.cardX, cell.cardY)
        return p.y + cell.cardH * 0.3 > 0 && p.y + cell.cardH * 0.3 < height - bottomClearance
            && p.x + cell.cardW * 0.3 > 0 && p.x + cell.cardW * 0.7 < width
    }

    FontMetrics {
        id: fontMetrics
        font: Qt.application.font
    }

    model: trayModel
    leftMargin: Ui.spacingLarge * 2
    rightMargin: Ui.spacingLarge * 2
    topMargin: shelf ? 0 : Ui.spacingLarge
    bottomMargin: shelf ? 0 : bottomClearance + Ui.spacingLarge * 2
    flow: shelf ? GridView.FlowTopToBottom : GridView.FlowLeftToRight
    flickableDirection: shelf ? Flickable.HorizontalFlick : Flickable.VerticalFlick
    cellWidth: shelf ? mainTray.cellWidth : Math.floor((width - leftMargin - rightMargin) / columns)
    cellHeight: cardW * Backend.theme.ratio + 2 * pad + Ui.spacingLarge * 3 + titleHeight
    cacheBuffer: cellHeight * 2
    clip: true
    focus: true
    keyNavigationEnabled: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    reuseItems: false
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: "Games"

    QQC2.ScrollBar.vertical: CScrollBar { visible: !grid.shelf }
    QQC2.ScrollBar.horizontal: CScrollBar { visible: grid.shelf && grid.contentWidth > grid.width }

    WheelAccel {
        flickable: grid
        horizontal: grid.shelf
        // The shelf scrolls sideways with Shift+wheel; a plain wheel scrolls the page.
        acceptedModifiers: grid.shelf ? Qt.ShiftModifier : Qt.KeyboardModifierMask
        step: grid.shelf ? grid.cellWidth : grid.cellHeight * 0.34
    }

    // Main tray: the favorites shelf above the grid (it scrolls away with it).
    header: grid.shelf || !Backend.settings.favoritesShelf ? null : shelfHeader
    Component {
        id: shelfHeader
        FavoritesShelf {
            width: grid.width - grid.leftMargin - grid.rightMargin
            tray: grid
            appRoot: grid.appRoot
        }
    }
    // The shelf loads and resizes after the grid (favorites added, removed): while the tray
    // is at its top, keep it there, so the shelf doesn't grow out of sight. (Set only by
    // scrolling: the header's own change moves the top, not the view.)
    property bool atTop: true
    onContentYChanged: atTop = contentY <= originY + 1
    // The same when the shelf comes or goes (Menu → Library → Favorites shelf).
    onHeaderItemChanged: if (!shelf && atTop) Qt.callLater(positionViewAtBeginning)
    Connections {
        target: grid.shelf ? null : grid.headerItem
        function onHeightChanged() {
            if (grid.atTop && !grid.appRoot.dragging) Qt.callLater(grid.positionViewAtBeginning)
        }
    }

    delegate: TrayCell {
        appRoot: grid.appRoot
    }

    Keys.onReturnPressed: if (currentItem) appRoot.choose(currentItem)
    Keys.onEnterPressed: if (currentItem) appRoot.choose(currentItem)
    // The focus ring only shows once the keyboard is being used, not on startup or after a click.
    property bool keyboardNav: false
    onActiveFocusChanged: if (!activeFocus) keyboardNav = false

    Keys.onPressed: (event) => {
        keyboardNav = true
        const menuKey = event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))
        if (menuKey && currentItem) {
            if (currentItem.out) appRoot.openDockMenu(currentItem.gameId)
            else currentItem.openMenu(false)
            event.accepted = true
        }
    }

    // One shared context menu for all cards (a menu per card made scrolling hitch).
    function closeMenus() { cardMenu.close() }  // demo harness
    function openCardMenu(cell, atPointer) {
        if (shelf) return mainTray.openCardMenu(cell, atPointer)
        cardMenu.cell = cell
        if (atPointer) cardMenu.popup()
        else cardMenu.popup(cell.card, cell.card.width / 2, cell.card.height / 3)
    }

    CMenu {
        id: cardMenu
        property Item cell: null
        readonly property bool installed: cell ? cell.installed : true

        QQC2.Action {
            text: cardMenu.installed ? "Play" : "Install"
            icon.name: cardMenu.installed ? "media-playback-start-symbolic" : "download-symbolic"
            onTriggered: grid.appRoot.quickPlay(cardMenu.cell)
        }
        QQC2.Action {
            text: "Take a Closer Look"
            icon.name: "zoom-in-symbolic"
            onTriggered: grid.appRoot.choose(cardMenu.cell)
        }
        QQC2.Action {
            readonly property bool fav: cardMenu.cell !== null && Backend.favorites.rowOf(cardMenu.cell.gameId) >= 0
            objectName: "optional"
            enabled: Backend.settings.favoritesShelf
            text: fav ? "Remove from Favorites" : "Add to Favorites"
            icon.name: "starred-symbolic"
            onTriggered: Backend.setFavorite(cardMenu.cell.gameId, !fav)
        }
        QQC2.Action {
            text: "Change Art…"
            icon.name: "insert-image-symbolic"
            enabled: !Backend.fake
            onTriggered: grid.appRoot.changeArt(cardMenu.cell.gameId, cardMenu.cell.title)
        }
        QQC2.Action {
            text: "Reposition Art…"
            icon.name: "transform-move-symbolic"
            enabled: !Backend.fake
            onTriggered: grid.appRoot.repositionArt(cardMenu.cell.gameId, cardMenu.cell.title)
        }
        QQC2.Action {
            text: "Change Header…"
            icon.name: "view-media-title-symbolic"
            onTriggered: grid.appRoot.changeHeader(cardMenu.cell.gameId, cardMenu.cell.title, cardMenu.cell.source)
        }
        QQC2.Action {
            text: "Rename…"
            icon.name: "edit-rename-symbolic"
            enabled: !Backend.fake
            onTriggered: grid.appRoot.renameGame(cardMenu.cell.gameId, cardMenu.cell.title)
        }
        QQC2.Action {
            text: "Edit Play Time…"
            icon.name: "chronometer-symbolic"
            objectName: "optional" // Steam keeps its own count
            enabled: cardMenu.cell !== null && Backend.playtimeEditable(cardMenu.cell.gameId)
            onTriggered: grid.appRoot.editPlaytime(cardMenu.cell.gameId, cardMenu.cell.title)
        }
        CMenuSeparator {}
        QQC2.Action {
            text: "Launch Without Slot"
            icon.name: "system-run-symbolic"
            checkable: true
            checked: cardMenu.cell !== null && cardMenu.cell.noSlot
            onTriggered: Backend.setNoSlot(cardMenu.cell.gameId, checked)
        }
        QQC2.Action {
            objectName: "optional"
            text: "Uninstall…"
            icon.name: "edit-delete-symbolic"
            enabled: cardMenu.cell !== null && cardMenu.cell.installed && cardMenu.cell.source === "steam"
            onTriggered: Backend.openUrl("steam://uninstall/" + cardMenu.cell.extId)
        }
        QQC2.Action {
            text: "Hide Game"
            icon.name: "view-hidden-symbolic"
            onTriggered: grid.appRoot.hideGame(cardMenu.cell.gameId, cardMenu.cell.title)
        }
    }

    remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: (100 * Backend.motion) }
    }
    displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: (200 * Backend.motion); easing.type: Easing.OutCubic }
    }
    add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: (100 * Backend.motion) }
    }
}
