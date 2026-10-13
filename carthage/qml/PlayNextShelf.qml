// A list's games as one grid (ListPage, and the search page's library results): Play Next's
// bookmarks (library games first, in the order they were added, then store games), Favorites,
// your own lists. Only shown while it has something.
import QtQuick
import Carthage

Column {
    id: pn

    property Item tray          // the main tray (for its geometry)
    property Item appRoot
    property var listModel: Backend.playNext
    property var storeItems: Backend.playNextStore
    property int maxRows: 0  // 0: every row; else only this many are built (the search page shows 2)
    readonly property int libraryCount: shelfLoader.item ? shelfLoader.item.count : 0
    readonly property int count: libraryCount + storeItems.length
    readonly property int columns: Math.max(1, tray.columns)

    visible: count > 0
    height: visible ? implicitHeight : 0

    // One grid for everything: the library games first (a one-part Tray), then the store games
    // in the next slots of the same rows, greyed out with a shopping bag. Choosing one opens its
    // store page.
    Item {
        id: area
        width: pn.width
        height: Math.ceil(pn.count / pn.columns) * pn.tray.cellHeight

        Loader {
            id: shelfLoader
            visible: pn.libraryCount > 0
            x: -pn.tray.leftMargin
            width: pn.tray.width
            readonly property int rows: Math.ceil(pn.libraryCount / pn.columns)
            // Only as tall as what shows: the cartridges below aren't built at all.
            height: (pn.maxRows > 0 ? Math.min(rows, pn.maxRows) : rows) * pn.tray.cellHeight
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
