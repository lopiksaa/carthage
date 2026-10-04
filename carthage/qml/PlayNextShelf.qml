// The Play Next shelf above the library: games bookmarked to play soon, from the library or
// the store. Library games come first (in the order they were added), then store games.
// Only shown while it has something; its title folds it shut.
import QtQuick
import Carthage

Column {
    id: pn

    property Item tray          // the main tray (for its geometry)
    property Item appRoot
    // Which list (the sidebar concept shows any list as a page, without the title).
    property var listModel: Backend.playNext
    property var storeItems: Backend.playNextStore
    property bool asPage: false
    readonly property var pal: Backend.theme.p
    readonly property int libraryCount: shelfLoader.item ? shelfLoader.item.count : 0
    readonly property int count: libraryCount + storeItems.length
    readonly property bool collapsed: !asPage && Backend.settings.playNextCollapsed
    readonly property int columns: Math.max(1, tray.columns)
    readonly property real leftX: tray.contentLeft - tray.leftMargin

    visible: count > 0
    height: visible ? implicitHeight : 0
    topPadding: asPage ? 0 : Ui.gapL
    spacing: Ui.gapS

    ShelfTitle {
        visible: !pn.asPage
        x: pn.leftX
        text: "Play Next"
        count: pn.count
        collapsed: pn.collapsed
        onToggled: Backend.settings.playNextCollapsed = !Backend.settings.playNextCollapsed
    }

    // One grid for everything: the library games first (a one-part Tray, like the favorites
    // shelf, loaded by URL for the same reason), then the store games in the next slots of
    // the same rows, greyed out with a shopping bag. Choosing one opens its store page.
    Item {
        id: area
        visible: !pn.collapsed
        width: pn.width
        height: visible ? Math.ceil(pn.count / pn.columns) * pn.tray.cellHeight : 0

        Loader {
            id: shelfLoader
            visible: pn.libraryCount > 0
            x: -pn.tray.leftMargin
            width: pn.tray.width
            height: Math.ceil(pn.libraryCount / pn.columns) * pn.tray.cellHeight
            Component.onCompleted: setSource(Qt.resolvedUrl("Tray.qml"), {
                shelf: true,
                trayModel: pn.listModel,
                mainTray: pn.tray,
                appRoot: pn.appRoot,
            })
            onLoaded: {
                item.trayModel = Qt.binding(() => pn.listModel)  // follows a page switching lists
                item.leftMargin = Qt.binding(() => pn.tray.leftMargin)
                item.rightMargin = Qt.binding(() => pn.tray.rightMargin)
                item.interactive = false
            }
        }

        Repeater {
            model: pn.storeItems
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int slot: pn.libraryCount + index  // right after the owned games
                // Where the tray would put a card in this slot (TrayCell's pocket).
                x: (slot % pn.columns) * pn.tray.cellWidth
                y: Math.floor(slot / pn.columns) * pn.tray.cellHeight
                width: pn.tray.cellWidth
                height: pn.tray.cellHeight
                StoreCard {
                    x: Math.round((parent.width - pn.tray.pocketW) / 2)
                    y: Ui.spacingLarge * 2
                    item: parent.modelData
                    forSale: true
                    cardW: pn.tray.cardW
                    appRoot: pn.appRoot
                    onChosen: (it, cart) => pn.appRoot.openStoreItem(it, pn.storeItems)
                }
            }
        }
    }
}
