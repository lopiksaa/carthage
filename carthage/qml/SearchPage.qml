// The search page (sidebar layout concept): one search for the library and the stores. A big
// field, filter chips (genres, price, on sale, store, order) and the results as cartridges:
// your games first, then the stores'. Works with no text too: pick chips and browse.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Flickable {
    id: page

    property Item tray      // the main tray, for the cartridge geometry
    property Item appRoot
    property bool showField: true  // off when the top bar's field drives the page
    signal chosen(var item, Item cart, var siblings)

    readonly property var pal: Backend.theme.p
    property alias text: field.text
    property var genres: []       // Steam tags, all required
    property var exGenres: []     // Steam tags to leave out
    property string price: ""     // "", "free", "10", "20"
    property bool sale: false
    property string store: "all"  // all | steam | epic
    property string sort: "top"   // top | new | rated | price
    property var results: []
    property string state_: "ready" // loading | ready | error
    property string warning: ""
    property int requestId: 0
    readonly property string term: text.trim()
    readonly property bool epicNeedsTerm: store === "epic" && term.length < 2
    readonly property bool hasFilters: genres.length > 0 || exGenres.length > 0 || price !== "" || sale || sort !== "top"
    readonly property bool libraryShown: (term.length >= 2 || genres.length > 0) && store === "all"

    function focusField() { field.forceActiveFocus() }
    function setGenres(list) { genres = list; contentY = 0 }
    // A genre chip goes: off → included → left out → off.
    function toggleGenre(tag) {
        if (genres.indexOf(tag) >= 0) {
            genres = genres.filter(t => t !== tag)
            exGenres = exGenres.concat([tag])
        } else if (exGenres.indexOf(tag) >= 0) {
            exGenres = exGenres.filter(t => t !== tag)
        } else {
            genres = genres.concat([tag])
        }
    }
    function clear() {
        text = ""
        clearFilters()
    }
    function clearFilters() {
        genres = []; exGenres = []; price = ""; sale = false; store = "all"; sort = "top"
    }
    function scheduleRefresh() {
        started = true
        state_ = "loading"
        results = []
        lastBatch = 0
        appending = false
        warning = ""
        delay.restart()
    }
    onStoreChanged: {
        if (store === "epic") {
            genres = []
            exGenres = []
            if (sort === "new" || sort === "rated") sort = "top"
        }
        scheduleRefresh()
    }
    // Load more: the next page of the same search, added below.
    property int pageNo: 1
    property int lastBatch: 0
    property bool appending: false
    readonly property bool canLoadMore: state_ === "ready" && lastBatch >= 10 && store !== "epic"
    function loadMore() {
        pageNo++
        requestId++
        appending = true
        state_ = "loading"
        Backend.store.browse("search" + requestId, {
            term: term, tags: genres, untags: exGenres, sale: sale, maxPrice: price, sort: sort, store: store, page: pageNo })
    }
    function take(list) {
        const got = shown(list)
        lastBatch = list.length
        if (appending) {
            const seen = {}
            for (const it of results) seen[it.key || it.appid] = true
            results = results.concat(got.filter(it => !seen[it.key || it.appid]))
        } else results = got
        appending = false
        state_ = "ready"
    }
    function refresh() {
        Backend.searchLibrary.filterText = term.length >= 2 ? term : ""
        Backend.searchLibrary.genreList = genres
        Backend.searchLibrary.genreExclude = exGenres
        requestId++
        pageNo = 1
        appending = false
        state_ = "loading"
        warning = ""
        results = []
        lastBatch = 0
        if (epicNeedsTerm) {
            results = []
            state_ = "ready"
            return
        }
        if (term.length >= 2 && !hasFilters && store === "all") Backend.store.search(term)
        else Backend.store.browse("search" + requestId, {
            term: term, tags: genres, untags: exGenres, sale: sale, maxPrice: price, sort: sort, store: store })
    }
    onTermChanged: scheduleRefresh()
    onGenresChanged: scheduleRefresh()
    onExGenresChanged: scheduleRefresh()
    onPriceChanged: scheduleRefresh()
    onSaleChanged: scheduleRefresh()
    onSortChanged: scheduleRefresh()
    Timer { id: delay; interval: 380; onTriggered: page.refresh() }
    // The first results load when the page is first shown, not at startup.
    property bool started: false
    onVisibleChanged: if (visible && !started) { started = true; refresh() }

    Connections {
        target: Backend.store
        function onBrowseReady(key, list) {
            if (key === "search" + page.requestId) page.take(list)
        }
        function onBrowseFailed(key) {
            if (key === "search" + page.requestId) page.state_ = "error"
        }
        function onBrowseWarning(key, message) {
            if (key === "search" + page.requestId) page.warning = message
        }
        function onSearchReady(t, list) {
            if (t === page.term && page.store === "all" && !page.hasFilters && !page.appending) page.take(list)
        }
        function onSearchWarning(t, message) {
            if (t === page.term && page.store === "all" && !page.hasFilters) page.warning = message
        }
        function onSearchFailed(t) {
            if (t === page.term && page.store !== "epic") page.state_ = "error"
        }
    }
    // The store filter for a text search (Steam's search doesn't take it), and owned games left
    // out of the store results (they're above, in the library).
    function shown(list) {
        return list.filter(it => !it.owned && (store === "all" || (it.store || "steam") === store))
    }

    contentHeight: col.height + 140
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: CScrollBar {}
    WheelAccel { flickable: page; step: 110 }
    AutoScroll { flickable: page }
    Keys.onEscapePressed: page.appRoot.navigateBack()

    // A filter chip: on (accent) or off.
    // A filter you can turn on and off: outlined when off, tinted with its color when on.
    component Chip: QQC2.AbstractButton {
        id: chip
        property bool on: false
        property bool excluded: false  // left out: red, with a minus
        property color tint: excluded ? "#c8453c" : Backend.theme.accent.accent
        property string iconName
        height: 30
        implicitWidth: chipRow.implicitWidth + 2 * Ui.gapM
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.CheckBox
        Accessible.name: text + (excluded ? ", left out" : "")
        Accessible.checked: on
        Keys.onReturnPressed: clicked()
        background: Rectangle {
            radius: height / 2
            readonly property bool lit: chip.on || chip.excluded
            color: lit ? Qt.alpha(chip.tint, chip.hovered ? 0.34 : 0.24)
                 : chip.hovered ? Qt.alpha(page.pal.trayText, 0.08) : "transparent"
            border.width: chip.visualFocus ? 2 : 1
            border.color: chip.visualFocus ? Ui.focusColor
                        : lit ? Qt.alpha(chip.tint, 0.9) : Qt.alpha(page.pal.trayText, 0.16)
        }
        contentItem: Item {
            implicitWidth: chipRow.implicitWidth
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6
                CIcon {
                    visible: chip.iconName !== "" || chip.excluded
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13
                    height: 13
                    source: chip.excluded ? "list-remove" : chip.iconName
                    color: chipLabel.color
                }
                Text {
                    id: chipLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.text
                    color: chip.on || chip.excluded || chip.hovered ? page.pal.trayText : Qt.alpha(page.pal.trayText, 0.72)
                    font.family: Ui.fontText
                    font.weight: chip.on || chip.excluded ? Font.Bold : Font.Medium
                    font.strikeout: chip.excluded
                    font.pixelSize: Ui.textBody
                }
            }
        }
    }
    // One choice of a few: a quiet track, the chosen one raised in it.
    component Segments: Rectangle {
        id: segs
        property var options: []   // [{ v, t }]
        property var value
        signal picked(var value)
        readonly property int current: options.findIndex(o => o.v === value)
        width: segRow.implicitWidth + 6
        height: 30
        radius: height / 2
        color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.22 : 0.08)
        border.width: 1
        border.color: Qt.alpha(page.pal.trayText, 0.10)
        Accessible.role: Accessible.PageTabList
        Rectangle {  // the chosen one
            readonly property Item at: segRepeater.itemAt(Math.max(0, segs.current))
            visible: segs.current >= 0 && at !== null
            x: at ? segRow.x + at.x : 0
            y: 3
            width: at ? at.width : 0
            height: parent.height - 6
            radius: height / 2
            color: Qt.alpha(page.pal.trayText, Backend.theme.dark ? 0.22 : 0.16)
            border.width: 1
            border.color: Qt.alpha(page.pal.trayText, 0.16)
            Behavior on x { NumberAnimation { duration: 160 * Backend.motion; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 160 * Backend.motion; easing.type: Easing.OutCubic } }
        }
        Row {
            id: segRow
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                id: segRepeater
                model: segs.options
                delegate: QQC2.AbstractButton {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === segs.current
                    height: 24
                    implicitWidth: segText.implicitWidth + 2 * Ui.gapM
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.t
                    Accessible.selected: chosen
                    Keys.onReturnPressed: clicked()
                    onClicked: segs.picked(modelData.v)
                    background: Rectangle {
                        radius: height / 2
                        color: "transparent"
                        border.width: seg.visualFocus ? 2 : 0
                        border.color: Ui.focusColor
                    }
                    contentItem: Text {
                        id: segText
                        text: seg.modelData.t
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: seg.chosen || seg.hovered ? page.pal.trayText : Qt.alpha(page.pal.trayText, 0.62)
                        font.family: Ui.fontText
                        font.weight: seg.chosen ? Font.Bold : Font.Medium
                        font.pixelSize: Ui.textBody
                    }
                }
            }
        }
    }
    component RowLabel: Text {
        width: 76
        height: 30
        verticalAlignment: Text.AlignVCenter
        color: page.pal.trayTextDim
        font.family: Ui.fontLabels
        font.weight: Font.Black
        font.pixelSize: Ui.textCaption
        font.letterSpacing: 1.5
        font.capitalization: Font.AllUppercase
    }

    Column {
        id: col
        x: page.tray.contentLeft
        width: page.tray.contentRight - page.tray.contentLeft
        y: Ui.spacingLarge
        spacing: Ui.gapM

        // The field.
        QQC2.TextField {
            id: field
            visible: page.showField
            width: parent.width
            height: visible ? 48 : 0
            leftPadding: 52
            rightPadding: 48
            placeholderText: "Search your games and the stores"
            placeholderTextColor: page.pal.trayTextDim
            color: page.pal.trayText
            font.family: Ui.fontText
            font.pixelSize: Ui.textLead
            font.weight: Font.DemiBold
            selectByMouse: true
            Accessible.name: "Search"
            Keys.onEscapePressed: page.appRoot.navigateBack()
            Keys.onDownPressed: page.forceActiveFocus()
            background: Rectangle {
                radius: Ui.radiusMedium + 4
                color: Qt.alpha(page.pal.trayText, 0.07)
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Backend.theme.accent.accent : Qt.alpha(page.pal.trayText, 0.2)
                CIcon {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    source: "search"
                    color: page.pal.trayTextDim
                }
            }
            CButton {
                visible: field.text !== ""
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                kind: "ghost"
                icon.name: "edit-clear"
                Accessible.name: "Clear the search"
                onClicked: { field.text = ""; field.forceActiveFocus() }
            }
        }

        // The chips.
        Row {
            visible: page.store !== "epic"
            objectName: "search_chips"  // (profiling)
            width: parent.width
            spacing: Ui.gapS
            RowLabel { text: "Genres" }
            Flow {
                width: parent.width - 76 - Ui.gapS
                spacing: 6
                Repeater {
                    model: Backend.store.categories
                    delegate: Chip {
                        required property var modelData
                        text: modelData.name
                        on: page.genres.indexOf(modelData.tag) >= 0
                        excluded: page.exGenres.indexOf(modelData.tag) >= 0
                        onClicked: page.toggleGenre(modelData.tag)
                    }
                }
            }
        }
        Flow {  // wraps in a narrow window
            width: parent.width
            spacing: Ui.gapS
            Row {  // a label wraps with its control
                spacing: Ui.gapS
                RowLabel { text: "Price" }
                Segments {
                    options: [{ v: "", t: "Any" }, { v: "free", t: "Free" }, { v: "10", t: "Under 10" }, { v: "20", t: "Under 20" }]
                    value: page.price
                    onPicked: (v) => page.price = v
                }
            }
            Item { width: Ui.gapS; height: 1 }
            Chip {
                text: "On Sale"
                iconName: "tag"
                tint: "#4c9a1a"  // the discount badges' green
                on: page.sale
                onClicked: page.sale = !page.sale
            }
        }
        Flow {  // wraps in a narrow window
            width: parent.width
            spacing: Ui.gapS
            Row {
                spacing: Ui.gapS
                RowLabel { text: "Store" }
                Segments {
                    options: [{ v: "all", t: "All Stores" }, { v: "steam", t: "Steam" }, { v: "epic", t: "Epic" }]
                    value: page.store
                    onPicked: (v) => page.store = v
                }
            }
            Item { width: Ui.gapS; height: 1 }
            Row {
                spacing: Ui.gapS
                RowLabel { text: "Order" }
                Segments {
                    options: page.store === "epic"
                             ? [{ v: "top", t: "Relevance" }, { v: "price", t: "Cheapest" }]
                             : [{ v: "top", t: page.term.length >= 2 ? "Relevance" : "Top Sellers" }, { v: "rated", t: "Best Rated" }, { v: "new", t: "Newest" }, { v: "price", t: "Cheapest" }]
                    value: page.sort
                    onPicked: (v) => page.sort = v
                    onOptionsChanged: if (page.store === "epic" && ["rated", "new"].includes(page.sort)) page.sort = "top"
                }
            }
        }
        Item { width: 1; height: Ui.gapS }

        // In your library.
        Item {
            objectName: "search_library"  // (profiling)
            visible: page.libraryShown && libShelf.count > 0
            width: parent.width
            height: visible ? libTitle.height + Ui.gapS + libClip.height : 0
            Row {
                id: libTitle
                spacing: Ui.gapM
                EngravedLabel { text: "In Your Library" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: libShelf.count + (libShelf.count === 1 ? " game" : " games")
                    color: page.pal.trayTextDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textCaption
                }
            }
            Item {
                id: libClip
                y: libTitle.height + Ui.gapS
                x: -page.tray.contentLeft + page.tray.leftMargin
                width: page.width
                // Two rows at most; the rest are in the library.
                height: Math.min(libShelf.height, 2 * page.tray.cellHeight)
                clip: true
                PlayNextShelf {
                    id: libShelf
                    // (libClip already starts at the tray's margin: the tray's columns exactly.)
                    width: page.width - page.tray.leftMargin - page.tray.rightMargin
                    asPage: true
                    tray: page.tray
                    appRoot: page.appRoot
                    listModel: Backend.searchLibrary
                    storeItems: []
                    maxRows: 2
                }
            }
        }

        // In the stores.
        Item {
            width: parent.width
            height: storesTitle.height
            Row {
                id: storesTitle
                spacing: Ui.gapM
                EngravedLabel { text: page.term.length >= 2 || page.hasFilters || page.store === "epic" ? "In the Stores" : "Popular Right Now" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                                        text: page.state_ === "loading" ? "Searching…"
                                                : page.state_ === "error" ? "Unavailable"
                                                : page.epicNeedsTerm ? "Search by name"
                                                : page.results.length === 0 && (page.term.length >= 2 || page.hasFilters)
                                                    ? "No results" : page.results.length + " games"
                    color: page.pal.trayTextDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textCaption
                }
            }
            CButton {
                visible: page.hasFilters || page.store !== "all"
                anchors.right: parent.right
                anchors.verticalCenter: storesTitle.verticalCenter
                kind: "ghost"
                text: "Clear Filters"
                icon.name: "edit-clear"
                onClicked: page.clearFilters()
            }
        }
        Text {
            // Only what applies to the filters in use (it used to mention genre filters with
            // none chosen).
            readonly property bool genreFilter: page.genres.length > 0 || page.exGenres.length > 0
            readonly property string note: page.store === "steam" || (page.store === "epic" && page.term.length < 2) ? ""
                : page.term.length < 2 ? "Epic needs a name search; browsing without one shows Steam results only."
                : page.store === "epic" ? (genreFilter ? "Epic supports name, price and sale filters. Genre filters show Steam results only." : "")
                : [genreFilter ? "Genre filters show Steam results only." : "",
                   page.sort === "rated" || page.sort === "new" ? "Rating and release rankings apply to Steam; Epic matches follow." : ""]
                  .filter(s => s).join(" ")
            visible: note !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: note
            color: page.pal.trayTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textCaption
        }
        Text {
            visible: page.warning !== "" || page.state_ === "error"
            width: parent.width
            text: page.warning || (page.store === "epic" ? "Couldn't reach Epic Games Store. Check your connection and try again."
                  : page.store === "all" ? "Couldn't reach Steam or Epic Games Store. Check your connection and try again."
                  : "Couldn't reach Steam. Check your connection and try again.")
            color: page.pal.trayTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        Grid {  // in the tray's columns, like the library results above
            id: resultsGrid  // (not `results`: that's the page's list)
            objectName: "search_results"  // (profiling)
            x: -page.tray.contentLeft + page.tray.leftMargin
            columns: page.tray.columns
            rowSpacing: Ui.gapL
            opacity: page.state_ === "loading" && !page.appending ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 120 * Backend.motion; easing.type: Easing.OutCubic } }
            Repeater {
                model: page.results
                delegate: Item {
                    required property var modelData
                    width: page.tray.cellWidth
                    height: resultCard.height
                    StoreCard {
                        id: resultCard
                        anchors.horizontalCenter: parent.horizontalCenter
                        item: parent.modelData
                        cardW: Backend.settings.cardWidth
                        appRoot: page.appRoot
                        onChosen: (it, cart) => page.chosen(it, cart, page.results)
                    }
                }
            }
        }
        Item {
            visible: page.canLoadMore || page.appending
            width: parent.width
            height: visible ? moreButton.height + Ui.gapL : 0
            CButton {
                id: moreButton
                anchors.horizontalCenter: parent.horizontalCenter
                y: Ui.gapL
                enabled: !page.appending
                text: page.appending ? "Loading…" : "Load More"
                onClicked: page.loadMore()
            }
        }
    }
}
