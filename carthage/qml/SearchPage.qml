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
    signal chosen(var item, Item cart, var siblings)

    readonly property var pal: Backend.theme.p
    property alias text: field.text
    property var genres: []       // Steam tags, all required
    property string price: ""     // "", "free", "10", "20"
    property bool sale: false
    property string store: "all"  // all | steam | epic
    property string sort: "top"   // top | new | rated | price
    property var results: []
    property string state_: "ready" // loading | ready | error
    property int requestId: 0
    readonly property string term: text.trim()
    readonly property bool hasFilters: genres.length > 0 || price !== "" || sale || sort !== "top"
    readonly property bool libraryShown: (term.length >= 2 || genres.length > 0) && store === "all"

    function focusField() { field.forceActiveFocus() }
    function setGenres(list) { genres = list; contentY = 0 }
    function toggleGenre(tag) {
        const i = genres.indexOf(tag)
        genres = i >= 0 ? genres.filter(t => t !== tag) : genres.concat([tag])
    }
    function clear() {
        text = ""; genres = []; price = ""; sale = false; store = "all"; sort = "top"
    }
    function refresh() {
        Backend.searchLibrary.filterText = term.length >= 2 ? term : ""
        Backend.searchLibrary.genreList = genres
        requestId++
        state_ = "loading"
        if (store === "epic" && term.length < 2) {
            results = []
            state_ = "ready"
            return
        }
        if (term.length >= 2 && !hasFilters) Backend.store.search(term)  // the best title matches
        else Backend.store.browse("search" + requestId, {
            term: term, tags: genres, sale: sale, maxPrice: price, sort: sort, store: store })
    }
    onTermChanged: { started = true; delay.restart() }
    onGenresChanged: delay.restart()
    onPriceChanged: delay.restart()
    onSaleChanged: delay.restart()
    onStoreChanged: delay.restart()
    onSortChanged: delay.restart()
    Timer { id: delay; interval: 380; onTriggered: page.refresh() }
    // The first results load when the page is first shown, not at startup.
    property bool started: false
    onVisibleChanged: if (visible && !started) { started = true; refresh() }

    Connections {
        target: Backend.store
        function onBrowseReady(key, list) {
            if (key === "search" + page.requestId) { page.results = page.shown(list); page.state_ = "ready" }
        }
        function onBrowseFailed(key) {
            if (key === "search" + page.requestId) page.state_ = "error"
        }
        function onSearchReady(t, list) {
            if (t === page.term && !page.hasFilters) { page.results = page.shown(list); page.state_ = "ready" }
        }
        function onSearchFailed(t) {
            if (t === page.term) page.state_ = "error"
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
    Keys.onEscapePressed: page.appRoot.navigateBack()

    // A filter chip: on (accent) or off.
    // A filter you can turn on and off: outlined when off, tinted with its color when on.
    component Chip: QQC2.AbstractButton {
        id: chip
        property bool on: false
        property color tint: Backend.theme.accent.accent
        property string iconName
        height: 30
        implicitWidth: chipRow.implicitWidth + 2 * Ui.gapM
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.checked: on
        Keys.onReturnPressed: clicked()
        background: Rectangle {
            radius: height / 2
            color: chip.on ? Qt.alpha(chip.tint, chip.hovered ? 0.34 : 0.24)
                 : chip.hovered ? Qt.alpha(page.pal.trayText, 0.08) : "transparent"
            border.width: chip.visualFocus ? 2 : 1
            border.color: chip.visualFocus ? Ui.focusColor
                        : chip.on ? Qt.alpha(chip.tint, 0.9) : Qt.alpha(page.pal.trayText, 0.16)
        }
        contentItem: Item {
            implicitWidth: chipRow.implicitWidth
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6
                CIcon {
                    visible: chip.iconName !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13
                    height: 13
                    source: chip.iconName
                    color: chipLabel.color
                }
                Text {
                    id: chipLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.text
                    color: chip.on || chip.hovered ? page.pal.trayText : Qt.alpha(page.pal.trayText, 0.72)
                    font.family: Ui.fontText
                    font.weight: chip.on ? Font.Bold : Font.Medium
                    font.pixelSize: Ui.textCaption + 1
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
                        font.pixelSize: Ui.textCaption + 1
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
            width: parent.width
            height: 54
            leftPadding: 52
            rightPadding: 48
            placeholderText: "Search your games and the stores"
            placeholderTextColor: page.pal.trayTextDim
            color: page.pal.trayText
            font.family: Ui.fontText
            font.pixelSize: Ui.textLead + 2
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
                    options: [{ v: "top", t: "Top Sellers" }, { v: "rated", t: "Best Rated" }, { v: "new", t: "Newest" }, { v: "price", t: "Cheapest" }]
                    value: page.sort
                    onPicked: (v) => page.sort = v
                }
            }
        }
        Item { width: 1; height: Ui.gapS }

        // In your library.
        Item {
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
                    x: page.tray.leftMargin
                    width: page.width - page.tray.leftMargin - page.tray.rightMargin
                    asPage: true
                    tray: page.tray
                    appRoot: page.appRoot
                    listModel: Backend.searchLibrary
                    storeItems: []
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
                EngravedLabel { text: page.term.length >= 2 || page.hasFilters ? "In the Stores" : "Popular Right Now" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.state_ === "loading" ? "Searching…" : page.results.length + " games"
                    color: page.pal.trayTextDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textCaption
                }
            }
            CButton {
                visible: page.term !== "" || page.genres.length > 0 || page.price !== "" || page.sale || page.store !== "all" || page.sort !== "top"
                anchors.right: parent.right
                anchors.verticalCenter: storesTitle.verticalCenter
                kind: "ghost"
                text: "Clear Filters"
                icon.name: "edit-clear"
                onClicked: page.clear()
            }
        }
        Text {
            visible: page.store === "epic" && page.term.length < 2
            width: parent.width
            wrapMode: Text.Wrap
            text: "Epic's store can only be searched by name: type one above."
            color: page.pal.trayTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
        }
        Text {
            visible: page.state_ === "error"
            text: "The stores didn't answer. Check the connection and try again."
            color: page.pal.trayTextDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
        }
        Flow {
            width: parent.width
            spacing: Ui.gapL
            opacity: page.state_ === "loading" ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Repeater {
                model: page.results
                delegate: StoreCard {
                    required property var modelData
                    item: modelData
                    cardW: Backend.settings.cardWidth
                    appRoot: page.appRoot
                    onChosen: (it, cart) => page.chosen(it, cart, page.results)
                }
            }
        }
    }
}
