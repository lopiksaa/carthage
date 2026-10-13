// The store as shelves of cartridges (Discover), or every category as tiles (Genres). Read-only:
// buying happens in each store. A category opens the search page with that genre (`genre`).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: view

    property Item appRoot
    property var sections: []
    property var spotlight: []
    property bool browsing: false    // the "All Categories" page
    function showCategories() { browsing = true }
    function backToStore() { browsing = false }
    // The page grid: the library tray's edges and columns, so every page lines up. Shelves
    // for the library's top genres ("Because You Play …", games you don't own).
    property Item tray
    readonly property real edge: tray.contentLeft
    readonly property real edgeRight: tray.width - tray.contentRight
    signal genre(var category)  // {name, tag}
    property var because: []  // [{key, title, items}]
    readonly property var topGenres: Backend.topGenres.slice(0, 2)
    function loadBecause() {
        for (const g of topGenres) Backend.store.browse("because:" + g.value, { tags: [g.value], sort: "rated" })
    }
    onTopGenresChanged: loadBecause()
    onBecauseChanged: shelfSettle.restart()
    function openCategory(c) { genre(c) }
    property var charts: []
    // Rebuilt once the lists settle (they arrive one by one): resetting the view while it's
    // still creating shelves destroys them.
    property var shelfModel: []
    function rebuildShelves() {
        shelfModel = sections.slice(0, 1)
            .concat(because)
            .concat(free.length ? [{ key: "free", title: "Free for a Limited Time", items: free }] : [])
            .concat(charts.length ? [{ key: "charts", title: "Most Played Right Now", items: charts }] : [])
            .concat(sections.slice(1))
            .filter(sec => sec.items.length > 0)
    }
    Timer { id: shelfSettle; interval: 150; onTriggered: view.rebuildShelves() }
    onSectionsChanged: shelfSettle.restart()
    onChartsChanged: shelfSettle.restart()
    onFreeChanged: shelfSettle.restart()
    property var free: []   // Free for a Limited Time (Steam and Epic)
    property string state_: "loading" // loading | ready | error
    property string error: ""
    property real bottomClearance: 0
    readonly property var pal: Backend.theme.p
    readonly property real cardW: Backend.settings.cardWidth

    signal chosen(var item, Item cart, var siblings) // siblings: the list it was chosen from (← → on its page)

    function load() {
        if (sections.length === 0) state_ = "loading"
        Backend.store.loadFeatured()
        Backend.store.loadSpotlight()
        Backend.store.loadCharts()
        Backend.store.loadFree()
        Backend.store.loadAllCategoryArt()
        if (because.length === 0) loadBecause()
    }
    readonly property bool hideAdult: Backend.settings.hideAdult
    onHideAdultChanged: load()

    Connections {
        target: Backend.store
        function onFeaturedReady(list) {
            view.sections = list
            view.state_ = "ready"
        }
        function onSpotlightReady(list) {
            // The banner usually arrives after the shelves: stay at the top so it doesn't grow
            // out of sight.
            const atTop = shelves.contentY <= shelves.originY - shelves.topMargin + 1
            view.spotlight = list
            if (atTop) Qt.callLater(() => shelves.contentY = shelves.originY - shelves.topMargin)
        }
        function onBrowseReady(key, list) {
            if (!key.startsWith("because:")) return
            const tag = parseInt(key.slice(8))
            const g = view.topGenres.find(x => x.value === tag)
            if (!g) return
            const sec = { key: key, title: "Because You Play " + g.text, items: list.filter(it => !it.owned).slice(0, 14) }
            view.because = view.because.filter(s => s.key !== key).concat([sec])
                .sort((a, b) => view.topGenres.findIndex(x => "because:" + x.value === a.key)
                              - view.topGenres.findIndex(x => "because:" + x.value === b.key))
        }
        function onChartsReady(list) { view.charts = list }
        function onFreeReady(list) { view.free = list }
        function onFailed(message) {
            if (view.sections.length === 0) {
                view.error = message
                view.state_ = "error"
            } else view.appRoot.notify(message)
        }
    }

    ListView {
        id: shelves
        objectName: "storeShelves"  // for the test harness
        visible: !view.browsing && view.state_ === "ready"
        anchors.fill: parent
        topMargin: 18
        bottomMargin: view.bottomClearance + Ui.gapXXL
        spacing: Ui.gapXL
        clip: true
        model: view.shelfModel
        header: Column {
          width: shelves.width
          spacing: Ui.gapL
          Item {
            width: shelves.width
            height: view.spotlight.length ? bannerItem.height + 14 : 0
            StoreBanner {
                id: bannerItem
                objectName: "storeBanner"  // for the test harness
                visible: view.spotlight.length > 0
                x: view.edge
                width: parent.width - view.edge - view.edgeRight
                height: implicitHeight
                items: view.spotlight
                appRoot: view.appRoot
                onChosen: (it) => view.chosen(it, null, view.spotlight)
            }
          }
        }
        // Categories come last, after the shelves.
        footer: Column {
          width: shelves.width
          topPadding: Ui.gapXL + Ui.gapS
          spacing: Ui.gapM
          Item {
            width: parent.width
            height: browseTitle.height
            EngravedLabel {
              id: browseTitle
              x: 28
              text: "Browse by Category"
            }
            CButton {
              anchors.right: parent.right
              anchors.rightMargin: 24
              anchors.verticalCenter: browseTitle.verticalCenter
              text: "All Categories"
              icon.name: "go-next-symbolic"
              iconAfter: true
              onClicked: view.showCategories()
            }
          }
          ListView {
            id: tileRow
            width: parent.width
            height: 110
            orientation: ListView.Horizontal
            spacing: Ui.gapL
            leftMargin: view.edge
            rightMargin: view.edgeRight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Backend.store.categories
            WheelAccel { flickable: tileRow; horizontal: true; step: 200; acceptedModifiers: Qt.ShiftModifier }
            delegate: Item {
              required property var modelData
              width: 170
              height: 110
              CategoryTile {
                y: 8
                width: 170
                height: 96
                compact: true
                name: modelData.name
                tag: modelData.tag
                onChosen: view.openCategory(modelData)
              }
            }
          }
        }
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar {}
        WheelAccel { flickable: shelves; step: 110 }
        AutoScroll { flickable: shelves }

        delegate: Column {
            id: shelf
            required property var modelData
            width: shelves.width
            spacing: Ui.gapM

            EngravedLabel {
                x: view.edge
                text: shelf.modelData.title
            }
            // The shelf's cartridges, laid out as chosen in Settings → Store.
            Loader {
                sourceComponent: Backend.settings.storeLayout === "scroll" ? sideways : rows
            }
            // In rows, like the library tray (columns as in the search results).
            Component {
                id: rows
                Grid {
                    id: grid
                    x: view.tray.leftMargin
                    readonly property real cellW: view.tray.cellWidth
                    columns: view.tray.columns
                    rowSpacing: Ui.gapL
                    Repeater {
                        // Whole rows only: a shelf ending in a half-empty row looks unfinished.
                        model: {
                            const all = shelf.modelData.items
                            return all.length > grid.columns ? all.slice(0, all.length - all.length % grid.columns) : all
                        }
                        delegate: Item {
                            required property var modelData
                            width: grid.cellW
                            height: card.height
                            StoreCard {
                                id: card
                                anchors.horizontalCenter: parent.horizontalCenter
                                item: parent.modelData
                                cardW: view.cardW
                                appRoot: view.appRoot
                                onChosen: (it, cart) => view.chosen(it, cart, shelf.modelData.items)
                            }
                        }
                    }
                }
            }
            // In one row that scrolls sideways (Shift + wheel).
            Component {
                id: sideways
                ListView {
                    id: row
                    width: shelves.width
                    height: view.cardW * Backend.theme.ratio + view.cardW * 0.07
                            + (shelf.modelData.key === "charts" ? 76 : 58)
                    orientation: ListView.Horizontal
                    leftMargin: view.edge
                    rightMargin: view.edgeRight
                    spacing: 22
                    boundsBehavior: Flickable.StopAtBounds
                    model: shelf.modelData.items
                    delegate: StoreCard {
                        required property var modelData
                        item: modelData
                        cardW: view.cardW
                        appRoot: view.appRoot
                        onChosen: (it, cart) => view.chosen(it, cart, shelf.modelData.items)
                    }
                    WheelAccel {
                        flickable: row
                        horizontal: true
                        acceptedModifiers: Qt.ShiftModifier
                        step: view.cardW * 0.8
                    }
                }
            }
        }
    }

    GridView {
        id: browseGrid
        visible: view.browsing
        anchors.fill: parent
        leftMargin: view.edge - Ui.gapS
        rightMargin: view.edgeRight - Ui.gapS
        topMargin: 18
        bottomMargin: view.bottomClearance + Ui.gapXXL
        clip: true
        model: Backend.store.categories
        readonly property real span: width - leftMargin - rightMargin
        readonly property int cols: Math.max(2, Math.floor(span / 236))
        cellWidth: Math.floor(span / cols)
        cellHeight: 140
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar {}
        WheelAccel { flickable: browseGrid; step: 110 }
        AutoScroll { flickable: browseGrid }
        delegate: Item {
            required property var modelData
            width: browseGrid.cellWidth
            height: browseGrid.cellHeight
            CategoryTile {
                anchors.fill: parent
                anchors.margins: Ui.gapS
                name: modelData.name
                tag: modelData.tag
                onChosen: view.openCategory(modelData)
            }
        }
    }

    CPlaceholder {
        anchors.centerIn: parent
        width: parent.width - 80
        visible: !view.browsing && view.state_ !== "ready"
        iconName: view.state_ === "error" ? "network-disconnect" : "view-refresh"
        text: view.state_ === "error" ? view.error : "Loading store…"
        actionText: view.state_ === "error" ? "Try Again" : ""
        onAction: view.load()
    }
}
