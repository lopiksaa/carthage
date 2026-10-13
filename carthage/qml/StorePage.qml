// A store game up close (GameView): its cartridge, price, where you own it, details and a
// button into the store, where buying happens.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

GameView {
    id: page

    property var item: ({})
    // Every store selling this game. The cartridge shows one at a time; the wheel, the store
    // chips or ↑ ↓ turn it.
    property var offers: []
    property int offerIndex: 0
    readonly property var offer: offers.length ? offers[Math.min(offerIndex, offers.length - 1)] : null
    readonly property string store: offer ? offer.store : (item.store || "steam")
    readonly property string storeName: Backend.store.storeNames[store] || "Store"
    readonly property bool steamShown: store === "steam"
    // The stores you own it on (from your library), and whether that's the one showing.
    readonly property var ownedOn: Backend.games.count, Backend.ownedStores(item.appid || 0, item.name || info.name || "")
    readonly property bool ownedHere: ownedOn.indexOf(store) >= 0
    readonly property string libraryId: steamShown && item.appid ? Backend.libraryIdForApp(item.appid) : ""
    readonly property var shown: steamShown || !offer ? info : offer
    property bool detailsIn: false   // the store's details for this game have arrived
    function keyOf(it) { return it.key || ("steam:" + it.appid) }
    function steamUrl() { return "steam://store/" + item.appid }
    readonly property var media: mediaGallery.media
    readonly property var pal: Backend.theme.p

    detailsObjectName: "storePageDetails"  // for the test harness
    showArrows: siblings.length > 1
    cardWheelEnabled: offers.length > 1
    eyebrow: storeName
    title: info.name || item.name || ""
    credits: Ui.creditsLine(info.developer, info.publisher, info.released)
    gallerySubtitle: [shown.price || item.price || "", info.reviews || ""].filter(x => x).join("  ·  ")
    mainButton: buyButton
    backdropUrl: info.background || item.hero || ""
    detailsPending: (item.appid || 0) > 0 && !detailsIn
    cardGame: ({
        // A game you own wears your library's art (the same as on your shelf).
        gameId: page.libraryId, title: page.item.name || "", source: page.store, sourceName: page.storeName.toUpperCase(),
        sourceIcon: page.store, extId: String(page.item.appid || ""), code: "", installed: true,
        artUrl: page.libraryId ? "" : page.item.capsuleLarge || page.item.capsule || "", artFallback: page.item.header || "",
        // The back: what an installed game's label says (STEAM - 570 - DOTA2).
        backLabel: [page.storeName.toUpperCase(), String(page.item.appid || ""), Backend.titleCode(page.item.name || "")]
                   .filter(x => x).join(" - "),
        label: (page.offer && !page.steamShown ? (page.offer.until || page.offer.price)
                : (page.info.price || page.item.price || page.storeName)).toUpperCase(),
    })

    onCloseRequested: close()
    onStepRequested: (dir) => step(dir)
    onCardWheel: (dir) => shuffle(dir)
    Keys.onUpPressed: shuffle(-1)
    Keys.onDownPressed: shuffle(1)

    // The list this game was chosen from: ← → step through it.
    property var siblings: []

    function openFor(it, list) {
        siblings = list || []
        show(it)
        backdrop.clear()
        appRoot.sound("pick")
        // It grows into place from the middle of where it will be.
        const s = 0.55
        flyIn(heroX + heroW * (1 - s) / 2, heroY + heroH * (1 - s) / 2, s)
    }
    function show(it) {
        item = it
        info = { name: it.name, price: it.price, original: it.original, discount: it.discount, owned: it.owned,
                 description: it.description || "" }
        detailsIn = false
        detailsLoading()
        offers = it.offers || []
        offerIndex = 0
        if (it.appid) Backend.store.loadDetails(it.appid)
        else if ((it.store || "") === "epic") Backend.store.loadEpicDetails(keyOf(it), it.name || "")
        // Get the games on either side ready, so ← → shows them at once.
        const list = siblings || []
        for (let k = 0; k < list.length; k++) {
            if (keyOf(list[k]) !== keyOf(it)) continue
            for (const n of [list[k - 1], list[k + 1]])
                if (n && n.appid) Backend.store.prefetchDetails(n.appid)
            break
        }
        Backend.store.loadOffers(keyOf(it), it.appid || 0, it.name || "",
                                 { price: it.price || "", original: it.original || "", discount: it.discount || 0 })
    }
    function step(dir) {
        if (!open || animating) return
        const list = siblings || []
        let i = -1
        for (let k = 0; k < list.length; k++) if (keyOf(list[k]) === keyOf(item)) { i = k; break }
        const next = i < 0 ? null : list[i + dir]
        if (!next) return nudge()
        stepTo(dir, () => show(next))
    }
    function close() {
        if (!open) return
        // It shrinks back into the middle as it fades.
        const s = 0.85
        flyOut(heroX + heroW * (1 - s) / 2, heroY + heroH * (1 - s) / 2, s, 0, null)
    }

    // Turning the cartridge to another store's offer.
    function shuffle(dir) {
        if (offers.length < 2 || animating || shuffleAnim.running) return
        appRoot.sound("hover")
        const next = (offerIndex + dir + offers.length) % offers.length
        if (motion <= 0) { offerIndex = next; return }
        shuffleAnim.dir = dir
        shuffleAnim.next = next
        shuffleAnim.base = Math.round(hero.spin / 360) * 360
        stopTurning()
        shuffleAnim.restart()
    }
    function pickOffer(i) {
        if (i === offerIndex || shuffleAnim.running) return
        if (motion <= 0) { offerIndex = i; return }
        appRoot.sound("hover")
        shuffleAnim.dir = i > offerIndex ? 1 : -1
        shuffleAnim.next = i
        shuffleAnim.base = Math.round(hero.spin / 360) * 360
        stopTurning()
        shuffleAnim.restart()
    }
    SequentialAnimation {
        id: shuffleAnim
        property int dir: 1
        property int next: 0
        property real base: 0  // the front face's angle
        NumberAnimation { target: page.hero; property: "spin"; to: shuffleAnim.base + shuffleAnim.dir * 90; duration: 110 * page.motion; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                page.offerIndex = shuffleAnim.next
                page.hero.spin = shuffleAnim.base - shuffleAnim.dir * 90
            }
        }
        NumberAnimation { target: page.hero; property: "spin"; to: shuffleAnim.base; duration: 180 * page.motion; easing.type: Easing.OutCubic }
    }

    Connections {
        target: Backend.store
        function onDetailsReady(appid, d) {
            if (appid === page.item.appid) { page.info = d; page.detailsIn = true }
        }
        function onEpicDetailsReady(key, d) {
            if (key === page.keyOf(page.item)) page.info = Object.assign({}, page.info, d)
        }
        function onOffersReady(key, list) {
            if (key !== page.keyOf(page.item)) return
            // Keep what the item already knew (e.g. Epic's "Free until …") for stores the
            // lookup didn't find.
            const had = page.item.offers || []
            const known = had.filter(o => !list.some(n => n.store === o.store))
            // A giveaway's end date only comes with the free-games list: keep that offer.
            const merged = list.map(n => had.find(o => o.store === n.store && o.until) || n)
            const cur = page.offer ? page.offer.store : ""
            page.offers = merged.concat(known)
            const i = page.offers.findIndex(o => o.store === cur)
            page.offerIndex = i >= 0 ? i : 0
        }
    }

    // Under the cartridge: every store selling it (and ITAD's credit, which its terms ask for).
    under: Column {
        width: page.heroW
        spacing: Ui.gapS
        Row {
            id: storeChips
            visible: page.offers.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Ui.gapS
            Repeater {
                model: page.offers
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool current: index === page.offerIndex
                    height: 30
                    width: chipRow.implicitWidth + 2 * Ui.gapM
                    radius: height / 2
                    color: current ? Ui.onScrim : (chipHover.hovered ? Ui.scrimControlHover : Ui.scrimControl)
                    border.width: activeFocus ? 2 : 0
                    border.color: Ui.focusColor
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.storeName + ", " + modelData.price
                    Accessible.checked: current
                    Keys.onReturnPressed: page.pickOffer(index)
                    Keys.onSpacePressed: page.pickOffer(index)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Ui.gapS
                        Text {
                            text: chip.modelData.storeName
                            color: chip.current ? "#141417" : Ui.onScrim
                            font.family: Ui.fontText
                            font.weight: Font.Black
                            font.pixelSize: Ui.textCaption
                        }
                        CIcon {
                            visible: page.ownedOn.indexOf(chip.modelData.store) >= 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            source: "checkmark-symbolic"
                            isMask: true
                            color: chip.current ? "#141417" : Backend.theme.led.green
                        }
                        Text {
                            text: chip.modelData.price
                            color: chip.current ? "#141417" : Ui.onScrimDim
                            font.family: Ui.fontText
                            font.weight: Font.Bold
                            font.pixelSize: Ui.textCaption
                        }
                    }
                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.pickOffer(chip.index) }
                }
            }
        }
        Text {
            visible: storeChips.visible && page.offers.some(o => o.via === "IsThereAnyDeal")
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.StyledText
            text: "Prices from <a href=\"https://isthereanydeal.com\">IsThereAnyDeal</a>"
            color: Ui.onScrimDim
            linkColor: Ui.onScrimDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textCaption
            onLinkActivated: (url) => Backend.openUrl(url)
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }

    // The price, and where you own it.
    pinnedExtra: [
        Row {
            spacing: Ui.gapM
            Rectangle {
                visible: (page.shown.discount || 0) > 0 && !page.ownedHere
                anchors.verticalCenter: parent.verticalCenter
                width: dtext.implicitWidth + 16
                height: 30
                radius: Ui.radiusSmall
                color: "#4c9a1a"
                Text {
                    id: dtext
                    anchors.centerIn: parent
                    text: "-" + (page.shown.discount || 0) + "%"
                    color: Ui.onScrim
                    font.family: Ui.fontText
                    font.weight: Font.Black
                    font.pixelSize: Ui.textLead
                }
            }
            Text {
                visible: (page.shown.original || "") !== "" && !page.ownedHere
                anchors.verticalCenter: parent.verticalCenter
                text: page.shown.original || ""
                color: Ui.onScrimFaint
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textLead
                font.strikeout: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.ownedHere ? "Already owned"
                    : page.steamShown && page.info.comingSoon ? "Coming soon"
                    : (page.shown.until || page.shown.price || "")
                color: Ui.onScrim
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
            }
            CIcon {
                visible: page.info.linux === true && Qt.platform.os === "linux"
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "computer-symbolic"
                isMask: true
                color: Ui.onScrimDim
                QQC2.ToolTip.visible: tuxHover.hovered
                QQC2.ToolTip.text: "Runs natively on Linux"
                HoverHandler { id: tuxHover }
            }
        },
        // A check by each store you own it on (you might own it on more than one).
        Row {
            visible: page.ownedOn.length > 0
            spacing: Ui.gapM
            Repeater {
                model: page.ownedOn
                delegate: Row {
                    required property string modelData
                    spacing: 6
                    CIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: "checkmark-symbolic"
                        isMask: true
                        color: Backend.theme.led.green
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Owned on " + (Backend.store.storeNames[modelData] || modelData)
                        color: Ui.onScrimDim
                        font.family: Ui.fontText
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textBody
                    }
                }
            }
        }
    ]

    // Buy (or Show in My Library), then Play Next as a small key beside it.
    actions: [
        CButton {
            id: buyButton
            opacity: page.standIn ? 0 : 1
            width: parent.width - nextKey.width - Ui.gapM
            big: true
            kind: "primary"
            readonly property string gid: page.steamShown && page.info.owned ? Backend.libraryIdForApp(page.item.appid || 0) : ""
            readonly property bool isFree: page.steamShown ? page.info.free === true
                                         : page.offer !== null && page.offer.free === true
            // On your Steam wishlist already (Carthage reads it): said so, not offered again.
            readonly property bool wished: Backend.store.wishlistIds, Backend.store.isWishlisted(page.item.appid || 0)
            text: gid ? "Show in My Library"
                : page.steamShown && page.info.comingSoon ? (wished ? "Wishlisted on Steam" : "Wishlist in Steam")
                : (isFree ? "Get on " : "Buy on ") + page.storeName
            icon.name: gid ? "view-grid-symbolic"
                     : page.steamShown && page.info.comingSoon && wished ? "checkmark-symbolic" : "internet-services-symbolic"
            onClicked: {
                if (gid) {
                    page.close()
                    page.appRoot.showOwned(gid)
                } else Backend.openUrl(page.steamShown || !page.offer ? page.steamUrl() : page.offer.url)
            }
        },
        CButton {
            id: nextKey
            // Mentioning playNextStore re-checks it whenever Play Next changes.
            readonly property bool next: Backend.playNextStore, Backend.isPlayNextStore(page.keyOf(page.item), page.item.appid || 0)
            kind: "scrim"
            width: buyButton.height
            height: buyButton.height
            icon.name: next ? "bookmark-filled-symbolic" : "bookmark-symbolic"
            Accessible.name: next ? "Remove from Play Next" : "Add to Play Next"
            QQC2.ToolTip.visible: tipWanted
            QQC2.ToolTip.text: Accessible.name
            QQC2.ToolTip.delay: 300
            // Remembers the store on show (Steam, Epic…) with its offer and price.
            onClicked: Backend.setPlayNextStore(Object.assign({}, page.item, {
                key: page.keyOf(page.item),
                store: page.store,
                name: page.item.name || page.info.name || "",
                price: page.shown.price || page.item.price || "",
                original: page.shown.original || "",
                discount: page.shown.discount || 0,
                offers: page.offer ? [page.offer].concat(page.offers.filter(o => o !== page.offer)) : (page.item.offers || []),
            }), !next)
        }
    ]

    details: [
        ReviewBadges {
            width: parent.width
            info: page.info
        },
        Text {
            visible: text !== ""
            width: parent.width
            text: page.info.description || ""
            color: Ui.onScrim
            font.family: Ui.fontText
            font.pixelSize: Ui.textLead
            lineHeight: 1.15
            wrapMode: Text.Wrap
        },
        FoldSection {
            width: parent.width
            title: "About This Game"
            text: page.info.about || ""
        },
        FoldSection {
            width: parent.width
            title: "Details"
            text: [
                [page.info.controller || "",
                 page.info.achievements ? page.info.achievements + (page.info.achievements === 1 ? " achievement" : " achievements") : "",
                 page.info.dlcCount ? page.info.dlcCount + " DLC" : "",
                 Qt.platform.os === "windows" ? (page.info.windows === false ? "Doesn't run on Windows" : "")
                     : page.info.linux ? "Runs natively on Linux" : "",
                 page.info.ageRating ? "Rated " + page.info.ageRating + "+" : ""].filter(x => x).join("  ·  "),
                (page.info.features || []).length ? "Features: " + page.info.features.join(", ") : "",
                (page.info.languages || []).length ? "Languages: " + page.info.languages.map(x => x.trim()).join(", ") : "",
                page.info.requirements ? "Minimum requirements: " + page.info.requirements : "",
            ].filter(x => x).join("\n\n")
        },
        CButton {
            visible: page.steamShown && page.info.owned === true
            kind: "scrim"
            text: "Open Store Page in Steam"
            icon.name: "internet-services-symbolic"
            onClicked: Backend.openUrl(page.steamUrl())
        },
        GameLinks {
            width: parent.width
            appid: page.item.appid || 0
            title: page.info.name || page.item.name || ""
            website: page.info.website || ""
            metacriticUrl: page.info.metacriticUrl || ""
        }
    ]
}
