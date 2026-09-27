// The store as shelves of cartridges, or search results as one grid. Read-only: buying happens
// in each store.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: view

    property Item appRoot
    property string query: ""
    property var sections: []
    property var results: []
    property var spotlight: []
    property var category: null      // {name, tag} while browsing a category
    property var categoryItems: []
    property bool browsing: false    // the "All Categories" page
    readonly property bool searching: query.trim().length >= 2
    readonly property bool gridMode: searching || category !== null
    property string gridState: "ready"
    function search() {
        gridState = "loading"
        Backend.store.search(view.query)
    }
    function reloadCategory() {
        gridState = "loading"
        Backend.store.loadCategory(category.tag)
    }
    function showCategories() {
        category = null
        browsing = true
    }
    function backToStore() {
        category = null
        browsing = false
    }
    function openCategory(c) {
        category = c
        categoryItems = []
        reloadCategory()
        resultsGrid.contentY = resultsGrid.originY - resultsGrid.topMargin
    }
    property var charts: []
    // Rebuilt once the lists settle (they arrive one by one): resetting the view while it's
    // still creating shelves destroys them.
    property var shelfModel: []
    function rebuildShelves() {
        shelfModel = (free.length ? [{ key: "free", title: "Free for a Limited Time", items: free }] : [])
            .concat(sections.slice(0, 1))
            .concat(charts.length ? [{ key: "charts", title: "Most Played Right Now", items: charts }] : [])
            .concat(sections.slice(1))
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

    signal bannerGo(int i)
    function showInBanner(name) {  // demo harness: turn the banner to a game by name
        const match = it => (it.name || "").toLowerCase().includes(name.toLowerCase())
        let i = view.spotlight.findIndex(match)
        if (i < 0) {
            for (const sec of view.sections) {
                const it = (sec.items || []).find(match)
                if (it) {
                    view.spotlight = [Object.assign({}, it, { banner: it.hero || it.header })].concat(view.spotlight)
                    i = 0
                    break
                }
            }
        }
        if (i >= 0) view.bannerGo(i)
        return i
    }
    function scrollTo(y) {  // demo harness
        shelves.contentY = y - shelves.topMargin
    }
    function load() {
        if (sections.length === 0) state_ = "loading"
        Backend.store.loadFeatured()
        Backend.store.loadSpotlight()
        Backend.store.loadCharts()
        Backend.store.loadFree()
        Backend.store.loadAllCategoryArt()
    }
    readonly property bool hideAdult: Backend.settings.hideAdult
    onHideAdultChanged: {
        load()
        if (category) reloadCategory()
        if (searching) search()
    }
    onQueryChanged: {
        searchDelay.restart()
        // From query itself: the searching binding may not have updated yet.
        if (query.trim().length >= 2) gridState = "loading"
    }
    Timer {
        id: searchDelay
        interval: 380
        onTriggered: if (view.query.trim().length >= 2) view.search()
    }

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
        function onCategoryReady(tag, list) {
            if (view.category && view.category.tag === tag) {
                view.categoryItems = list
                if (!view.searching) view.gridState = "ready"
            }
        }
        function onCategoryFailed(tag) {
            if (view.category && view.category.tag === tag && !view.searching) view.gridState = "error"
        }
        function onSearchFailed(term) {
            if (term === view.query.trim()) view.gridState = "error"
        }
        function onChartsReady(list) { view.charts = list }
        function onFreeReady(list) { view.free = list }
        function onSearchReady(term, list) {
            if (term === view.query.trim()) {
                view.results = list
                view.gridState = "ready"
            }
        }
        function onFailed(message) {
            if (view.sections.length === 0) {
                view.error = message
                view.state_ = "error"
            } else view.appRoot.notify(message)
        }
    }

    ListView {
        id: shelves
        visible: !view.gridMode && !view.browsing && view.state_ === "ready"
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
                visible: view.spotlight.length > 0
                x: 24
                width: parent.width - 48
                height: implicitHeight
                items: view.spotlight
                appRoot: view.appRoot
                onChosen: (it) => view.chosen(it, null, view.spotlight)
                Connections {
                    target: view
                    function onBannerGo(i) { bannerItem.go(i) }
                }
            }
          }
          Column {
            width: shelves.width
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
                onClicked: view.showCategories()
              }
            }
            ListView {
              id: tileRow
              width: parent.width
              height: 110
              orientation: ListView.Horizontal
              spacing: Ui.gapL
              leftMargin: 28
              rightMargin: 28
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
            Item { width: 1; height: Ui.gapXL + Ui.gapS }
          }
        }
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar {}
        WheelAccel { flickable: shelves; step: 110 }

        delegate: Column {
            id: shelf
            required property var modelData
            width: shelves.width
            spacing: Ui.gapM

            EngravedLabel {
                x: 28
                text: shelf.modelData.title
            }
            // Exactly as tall as its cards, so every shelf is spaced the same.
            Item {
                width: parent.width
                height: row.height
                ListView {
                    id: row
                    x: 0
                    width: parent.width
                    height: view.cardW * Backend.theme.ratio + view.cardW * 0.07
                            + (shelf.modelData.key === "charts" ? 76 : 58)
                    orientation: ListView.Horizontal
                    leftMargin: 32
                    rightMargin: 32
                    spacing: 22
                    clip: false
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
        visible: view.browsing && !view.gridMode
        anchors.fill: parent
        leftMargin: 24
        rightMargin: 24
        topMargin: 18
        bottomMargin: view.bottomClearance + Ui.gapXXL
        clip: true
        model: Backend.store.categories
        readonly property int cols: Math.max(2, Math.floor((width - 48) / 236))
        cellWidth: Math.floor((width - 48) / cols)
        cellHeight: 140
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar {}
        WheelAccel { flickable: browseGrid; step: 110 }
        header: Row {
            height: 60
            spacing: Ui.gapL
            CButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Store"
                icon.name: "go-previous-symbolic"
                onClicked: view.backToStore()
            }
            EngravedLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "All Categories"
                pixelSize: Ui.textTitle
            }
        }
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

    GridView {
        id: resultsGrid
        visible: view.gridMode
        anchors.fill: parent
        bottomMargin: view.bottomClearance + Ui.gapXXL
        leftMargin: 24
        rightMargin: 24
        topMargin: 18
        clip: true
        model: view.query.trim().length >= 2 ? view.results : view.categoryItems
        header: Column {
            visible: view.category !== null && view.query.trim().length < 2
            width: resultsGrid.width - 48
            height: visible ? implicitHeight + 10 : 0
            spacing: Ui.gapM
            Row {
                spacing: Ui.gapL
                CButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Categories"
                    icon.name: "go-previous-symbolic"
                    onClicked: view.showCategories()
                }
                EngravedLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.category ? view.category.name : ""
                    pixelSize: Ui.textTitle
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Top sellers"
                    color: view.pal.trayTextDim
                    font.family: "Nunito"
                    font.pixelSize: Ui.textLead
                }
            }
        }
        readonly property int cols: Math.max(1, Math.floor((width - 48) / (view.cardW + 40)))
        cellWidth: Math.floor((width - 48) / cols)
        cellHeight: view.cardW * Backend.theme.ratio + 90
        QQC2.ScrollBar.vertical: CScrollBar {}
        WheelAccel { flickable: resultsGrid; step: resultsGrid.cellHeight * 0.34 }
        delegate: Item {
            required property var modelData
            width: resultsGrid.cellWidth
            height: resultsGrid.cellHeight
            StoreCard {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                item: modelData
                cardW: view.cardW
                appRoot: view.appRoot
                onChosen: (it, cart) => view.chosen(it, cart, resultsGrid.model)
            }
        }
        CPlaceholder {
            anchors.centerIn: parent
            width: parent.width - 80
            visible: resultsGrid.count === 0 && (view.searching || view.category !== null)
            iconName: view.gridState === "error" ? "network-disconnect"
                    : view.gridState === "loading" ? "view-refresh" : "search"
            readonly property string categoryName: view.category ? view.category.name : ""
            text: view.gridState === "error" ? "Couldn't reach the Steam store. Check your connection."
                : view.gridState === "loading" ? (view.searching ? "Searching the store…" : "Loading " + categoryName + "…")
                : view.searching ? "Nothing in the store matches “" + view.query.trim() + "”"
                : "Nothing in " + categoryName + " right now"
            actionText: view.gridState === "error" ? "Try Again" : ""
            onAction: view.searching ? view.search() : view.reloadCategory()
        }
    }

    CPlaceholder {
        anchors.centerIn: parent
        width: parent.width - 80
        visible: !view.gridMode && !view.browsing && view.state_ !== "ready"
        iconName: view.state_ === "error" ? "network-disconnect" : "view-refresh"
        text: view.state_ === "error" ? view.error : "Opening the Steam store…"
        actionText: view.state_ === "error" ? "Try Again" : ""
        onAction: view.load()
    }
}
