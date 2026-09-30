// A store game up close: its cartridge, price, details and a button into the store, where
// buying happens.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Effects

FocusScope {
    id: page

    property Item appRoot
    property Item stage
    property bool open: false
    property var item: ({})
    property var info: ({})
    // Every store selling this game. The cartridge shows one at a time; the wheel, the store
    // chips or ↑ ↓ turn it.
    property var offers: []
    property int offerIndex: 0
    readonly property var offer: offers.length ? offers[Math.min(offerIndex, offers.length - 1)] : null
    readonly property string store: offer ? offer.store : (item.store || "steam")
    readonly property string storeName: Backend.store.storeNames[store] || "Store"
    readonly property bool steamShown: store === "steam"
    readonly property var shown: steamShown || !offer ? info : offer
    function keyOf(it) { return it.key || ("steam:" + it.appid) }
    property real level: 0
    property real spin: 0
    property real cardScale: 1

    readonly property bool tilting: cardHover.hovered && !spinDrag.active && open && motion > 0
                                    && Backend.settings.tiltEnabled
    property real tiltX: tilting ? -(cardHover.point.position.y / cardZone.height - 0.5) * 14 : 0
    property real tiltY: tilting ? (cardHover.point.position.x / cardZone.width - 0.5) * 14 : 0
    Behavior on tiltX { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }
    Behavior on tiltY { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }
    property real dragTilt: 0
    IdleDrift {
        id: drift
        active: page.open && !openAnim.running && !settleAnim.running && !spinDrag.active && !cardHover.hovered
        motion: page.motion
    }

    function settle(velocityX) {
        const coast = spin + Math.max(-540, Math.min(540, velocityX * 0.25))
        settleAnim.spinTo = Math.round(coast / 180) * 180
        if (motion <= 0) { spin = settleAnim.spinTo; dragTilt = 0; return }
        settleAnim.restart()
        if (Math.abs(settleAnim.spinTo - spin) >= 90) appRoot.sound("hover")
    }
    function flip() {
        settleAnim.spinTo = Math.round(spin / 180) * 180 + 180
        if (motion <= 0) { spin = settleAnim.spinTo; return }
        settleAnim.restart()
        appRoot.sound("hover")
    }
    ParallelAnimation {
        id: settleAnim
        property real spinTo: 0
        NumberAnimation {
            target: page
            property: "spin"
            to: settleAnim.spinTo
            duration: Math.min(900, 260 + Math.abs(settleAnim.spinTo - page.spin) * 1.1) * page.motion
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
        NumberAnimation { target: page; property: "dragTilt"; to: 0; duration: 380 * page.motion; easing.type: Easing.OutBack }
        onFinished: page.spin = ((page.spin % 360) + 360) % 360
    }
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property var pal: Backend.theme.p

    readonly property real panelW: Math.min(Ui.detailsWidth, width - 64)
    readonly property bool wide: width >= 300 + 56 + panelW + 96
    readonly property real heroH: wide ? Math.min(height * 0.68, 540) : Math.min(height * 0.38, 330)
    readonly property real heroW: Math.round(heroH / Backend.theme.ratio)

    visible: level > 0.001 || open

    // The list this game was chosen from: ← → step through it.
    property var siblings: []
    property real swapFade: 1 // dips while stepping to the next game
    property int swapDir: 1   // which way the details move meanwhile (with the card's turn)

    function openFor(it, list) {
        siblings = list || []
        show(it)
        open = true
        appRoot.sound("pick")
        forceActiveFocus()
        if (motion <= 0) { level = 1; spin = 0; cardScale = 1; return }
        openAnim.restart()
    }
    function show(it) {
        item = it
        info = { name: it.name, price: it.price, original: it.original, discount: it.discount, owned: it.owned,
                 description: it.description || "" }
        offers = it.offers || []
        offerIndex = 0
        if (it.appid) Backend.store.loadDetails(it.appid)
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
        resetGallery()
        details.contentY = 0
    }
    function step(dir) {
        if (!open || openAnim.running || closeAnim.running || stepAnim.running) return
        const list = siblings || []
        let i = -1
        for (let k = 0; k < list.length; k++) if (keyOf(list[k]) === keyOf(item)) { i = k; break }
        const next = i < 0 ? null : list[i + dir]
        if (!next) {
            if (motion > 0) edgeNudge.restart()
            return
        }
        appRoot.sound("hover")
        stepAnim.dir = dir
        stepAnim.next = next
        swapDir = -dir
        if (motion <= 0) { show(next); return }
        stepAnim.restart()
    }
    SequentialAnimation {
        id: stepAnim
        property int dir: 1
        property var next: ({})
        ParallelAnimation {
            NumberAnimation { target: page; property: "spin"; to: page.spin + stepAnim.dir * 90; duration: 150 * page.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: page; property: "cardScale"; to: 0.9; duration: 150 * page.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: page; property: "swapFade"; to: 0; duration: 120 * page.motion }
        }
        ScriptAction {
            script: {
                page.show(stepAnim.next)
                page.spin = -stepAnim.dir * 90
                page.swapDir = stepAnim.dir
            }
        }
        ParallelAnimation {
            NumberAnimation { target: page; property: "spin"; to: 0; duration: 240 * page.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: page; property: "cardScale"; to: 1; duration: 240 * page.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: page; property: "swapFade"; to: 1; duration: 200 * page.motion }
        }
    }
    SequentialAnimation {
        id: edgeNudge
        NumberAnimation { target: page; property: "spin"; to: 8; duration: 60 }
        NumberAnimation { target: page; property: "spin"; to: -8; duration: 90 }
        NumberAnimation { target: page; property: "spin"; to: 0; duration: 60 }
    }

    function shuffle(dir) {
        if (offers.length < 2 || stepAnim.running || shuffleAnim.running) return
        appRoot.sound("hover")
        const next = (offerIndex + dir + offers.length) % offers.length
        if (motion <= 0) { offerIndex = next; return }
        shuffleAnim.dir = dir
        shuffleAnim.next = next
        shuffleAnim.base = Math.round(spin / 360) * 360
        shuffleAnim.restart()
    }
    function pickOffer(i) {
        if (i === offerIndex || shuffleAnim.running) return
        if (motion <= 0) { offerIndex = i; return }
        appRoot.sound("hover")
        shuffleAnim.dir = i > offerIndex ? 1 : -1
        shuffleAnim.next = i
        shuffleAnim.base = Math.round(spin / 360) * 360
        shuffleAnim.restart()
    }
    SequentialAnimation {
        id: shuffleAnim
        property int dir: 1
        property int next: 0
        property real base: 0  // the front face's angle
        NumberAnimation { target: page; property: "spin"; to: shuffleAnim.base + shuffleAnim.dir * 90; duration: 110 * page.motion; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                page.offerIndex = shuffleAnim.next
                page.spin = shuffleAnim.base - shuffleAnim.dir * 90
            }
        }
        NumberAnimation { target: page; property: "spin"; to: shuffleAnim.base; duration: 180 * page.motion; easing.type: Easing.OutCubic }
    }

    function close() {
        if (!open) return
        resetGallery()
        open = false
        if (motion <= 0) { level = 0; return }
        closeAnim.restart()
    }
    function steamUrl() { return "steam://store/" + item.appid }
    readonly property var media: mediaGallery.media

    Keys.onEscapePressed: close()
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: shuffle(-1)
    Keys.onDownPressed: shuffle(1)
    function scrollDetails(y) { details.contentY = y }  // demo harness

    Connections {
        target: Backend.store
        function onDetailsReady(appid, d) {
            if (appid === page.item.appid) page.info = d
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

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: page; property: "level"; from: 0; to: 1; duration: 220 * page.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: page; property: "cardScale"; from: 0.55; to: 1; duration: 480 * page.motion; easing.type: Easing.OutCubic }
        NumberAnimation { target: page; property: "spin"; from: 0; to: 360; duration: 480 * page.motion; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: page; property: "level"; to: 0; duration: 200 * page.motion; easing.type: Easing.InQuad }
        NumberAnimation { target: page; property: "cardScale"; to: 0.85; duration: 200 * page.motion; easing.type: Easing.InQuad }
    }

    ShaderEffectSource {
        id: src
        sourceItem: page.stage
        live: page.visible
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        opacity: page.level
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.05, Backend.theme.dark ? 0.72 : 0.64)
        opacity: page.level
    }
    MouseArea {
        anchors.fill: parent
        enabled: page.open
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: page.close()
        onWheel: (w) => w.accepted = true
    }

    Card3D {
        id: card
        x: page.wide ? Math.round((page.width - (page.heroW + 56 + page.panelW)) / 2) - (width - page.heroW) / 2
                     : Math.round((page.width - width) / 2)
        y: page.wide ? Math.round((page.height - height) / 2) : 20 - (height - page.heroH) / 2 + page.heroH * 0.1
        width: page.heroW * 2.1
        height: page.heroH * 1.35
        cardHeight: page.heroH
        opacity: page.level
        scale: page.cardScale
        spin: page.spin + drift.turn
        tiltX: page.tiltX + page.dragTilt + drift.tip
        tiltY: page.tiltY
        transform: [
            Translate { y: drift.float },
            Translate { x: -page.galleryLevel * (page.cardLeft + page.heroW - page.peekW) }
        ]
        game: ({
            gameId: "", title: page.item.name || "", source: page.store, sourceName: page.storeName.toUpperCase(),
            sourceIcon: page.store, extId: String(page.item.appid || ""), code: "", installed: true,
            artUrl: page.item.capsuleLarge || page.item.capsule || "", artFallback: page.item.header || "",
            label: (page.offer && !page.steamShown ? (page.offer.until || page.offer.price)
                    : (page.info.price || page.item.price || page.storeName)).toUpperCase(),
        })
    }

    // The 3D view is larger than the card.
    Item {
        id: cardZone
        anchors.centerIn: card
        width: page.heroW
        height: page.heroH
        enabled: page.open
        transform: Translate { x: -page.galleryLevel * (page.cardLeft + page.heroW - page.peekW) }
        HoverHandler {
            id: cardHover
            cursorShape: spinDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
        DragHandler {
            id: spinDrag
            target: null
            property real startSpin: 0
            onActiveChanged: {
                if (active) { settleAnim.stop(); openAnim.stop(); page.cardScale = 1; startSpin = page.spin }
                else page.settle(centroid.velocity.x)
            }
            onTranslationChanged: {
                if (!active) return
                page.spin = startSpin + translation.x * 0.55
                page.dragTilt = Math.max(-30, Math.min(30, -translation.y * 0.25))
            }
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: page.galleryMode ? page.exitGallery() : page.flip()
        }
        WheelHandler {
            enabled: page.offers.length > 1 && !page.galleryMode
            property real acc: 0
            onWheel: (ev) => {
                acc += ev.angleDelta.y || ev.angleDelta.x
                if (Math.abs(acc) >= 120) {
                    page.shuffle(acc < 0 ? 1 : -1)
                    acc = 0
                }
            }
        }
    }

    // ITAD's terms ask for a mention.
    Text {
        visible: storeChips.visible && page.offers.some(o => o.via === "IsThereAnyDeal")
        anchors.horizontalCenter: storeChips.horizontalCenter
        y: storeChips.y + storeChips.height + Ui.gapS
        opacity: storeChips.opacity
        textFormat: Text.StyledText
        text: "Prices from <a href=\"https://isthereanydeal.com\">IsThereAnyDeal</a>"
        color: Ui.onScrimDim
        linkColor: Ui.onScrimDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textCaption
        onLinkActivated: (url) => Backend.openUrl(url)
        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }

    Row {
        id: storeChips
        visible: page.offers.length > 1 && page.wide
        anchors.horizontalCenter: cardZone.horizontalCenter
        y: cardZone.y + cardZone.height + Ui.gapL
        spacing: Ui.gapS
        opacity: page.level * (1 - page.galleryLevel)
        enabled: page.open && !page.galleryMode
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

    // Scrolling down through the screenshots turns the page into its gallery (GalleryMorph).
    readonly property real peekW: 64
    readonly property real cardLeft: card.x + (card.width - page.heroW) / 2
    readonly property real panelBaseX: page.wide ? card.x + (card.width + page.heroW) / 2 + 56 : Math.round((page.width - page.panelW) / 2)
    readonly property real panelGalleryX: peekW + 56
    readonly property bool galleryMode: morph.galleryMode
    readonly property real galleryLevel: morph.level
    function resetGallery() { morph.reset() }  // no animation: closing or showing another game
    function exitGallery() {
        morph.exit()
        page.forceActiveFocus()
    }

    GalleryView {
        id: galleryView
        x: page.panelGalleryX + (1 - page.galleryLevel) * 40
        y: Ui.gapXL
        width: page.width - page.panelGalleryX - 72
        height: page.height - 2 * Ui.gapXL
        opacity: page.level * morph.galleryOpacity
        visible: opacity > 0.01 || morph.morphing
        enabled: page.galleryMode
        morphing: morph.morphing
        info: page.info
        appRoot: page.appRoot
        title: page.info.name || page.item.name || ""
        subtitle: [page.shown.price || page.item.price || "", page.info.reviews || ""].filter(x => x).join("  ·  ")
        actionText: buyButton.text
        actionIcon: buyButton.icon.name
        onAction: buyButton.clicked()
        onBack: page.exitGallery()
    }

    Item {
        id: detailsPanel
        readonly property real avail: page.wide ? page.height - 80 : page.height - (20 + page.heroH + 24) - 20
        x: page.panelBaseX - page.galleryLevel * 40
        y: page.wide ? Math.round((page.height - height) / 2) : 20 + page.heroH + 24
        width: details.width
        height: pinned.height + Ui.gapL + details.height
        opacity: page.level * page.swapFade * morph.detailsOpacity
        enabled: !page.galleryMode
        visible: opacity > 0.01 || morph.morphing
        transform: Translate { x: (1 - page.level) * 28 + (1 - page.swapFade) * 28 * page.swapDir }

        Column {
            id: pinned
            width: page.panelW
            spacing: Ui.gapL
            Column {
                width: parent.width
                spacing: Ui.gapS
                Text {
                    text: [page.storeName].concat(page.info.genres || []).join("  ·  ").toUpperCase()
                    color: Ui.onScrimDim
                    font.family: Ui.fontLabels
                    font.weight: Font.Black
                    font.pixelSize: Ui.textCaption
                    font.letterSpacing: 2
                    width: parent.width
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: page.info.name || page.item.name || ""
                    color: Ui.onScrim
                    font.family: Ui.fontTitles
                    font.weight: Font.Black
                    font.pixelSize: Ui.textDisplay
                    lineHeight: 0.95
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    textFormat: Text.StyledText
                    text: Ui.creditsLine(page.info.developer, page.info.publisher, page.info.released)
                    color: Ui.onScrimDim
                    linkColor: Ui.onScrimDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textLead
                    wrapMode: Text.Wrap
                    onLinkActivated: (url) => Backend.openUrl(url)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }

            Row {
                spacing: Ui.gapM
                Rectangle {
                    visible: (page.shown.discount || 0) > 0
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
                    visible: (page.shown.original || "") !== ""
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
                    text: page.steamShown && page.info.owned ? "In your library"
                        : page.steamShown && page.info.comingSoon ? "Coming soon"
                        : (page.shown.until || page.shown.price || "")
                    color: Ui.onScrim
                    font.family: Ui.fontText
                    font.weight: Font.Black
                    font.pixelSize: Ui.textTitle
                }
                CIcon {
                    visible: page.info.linux === true
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
            }

            CButton {
                id: buyButton
                width: parent.width
                big: true
                kind: "primary"
                opacity: morph.morphing ? 0 : 1
                readonly property string gid: page.steamShown && page.info.owned ? Backend.libraryIdForApp(page.item.appid || 0) : ""
                readonly property bool isFree: page.steamShown ? page.info.free === true
                                             : page.offer !== null && page.offer.free === true
                text: gid ? "Show in My Library"
                    : page.steamShown && page.info.comingSoon ? "Wishlist in Steam"
                    : (isFree ? "Get on " : "Buy on ") + page.storeName
                icon.name: gid ? "view-grid-symbolic" : "internet-services-symbolic"
                onClicked: {
                    if (gid) {
                        page.close()
                        page.appRoot.showOwned(gid)
                    } else Backend.openUrl(page.steamShown || !page.offer ? page.steamUrl() : page.offer.url)
                }
            }
            CButton {
                visible: page.steamShown && page.info.owned === true
                kind: "scrim"
                text: "Open Store Page in Steam"
                icon.name: "internet-services-symbolic"
                onClicked: Backend.openUrl(page.steamUrl())
            }

        }

        Flickable {
            id: details
            y: pinned.height + Ui.gapL
            width: page.panelW + (contentHeight > height ? Ui.gapL : 0)
            height: Math.max(0, Math.min(col.height, detailsPanel.avail - pinned.height - Ui.gapL))
            contentHeight: Math.max(col.height, morph.neededContentHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelAccel { id: detailsWheel; flickable: details; step: 90 }
            QQC2.ScrollBar.vertical: CScrollBar { onDark: true }

            Column {
                id: col
                width: page.panelW
                spacing: Ui.gapL
                ReviewBadges {
                    width: parent.width
                    info: page.info
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    text: page.info.description || ""
                    color: Ui.onScrim
                    font.family: Ui.fontText
                    font.pixelSize: Ui.textLead
                    lineHeight: 1.15
                    wrapMode: Text.Wrap
                }

                Flow {
                    width: parent.width
                    spacing: Ui.gapS
                    Repeater {
                        model: [
                            page.info.controller || "",
                            page.info.achievements ? page.info.achievements + " achievements" : "",
                            page.info.dlcCount ? page.info.dlcCount + " DLC" : "",
                            (page.info.languages || []).length ? (page.info.languages || []).length + " languages" : "",
                            page.info.linux ? "Native Linux" : "",
                            page.info.ageRating ? page.info.ageRating + "+" : "",
                        ].filter(x => x)
                        delegate: Rectangle {
                            required property var modelData
                            height: 28
                            width: chipText.implicitWidth + 18
                            radius: 14
                            color: Ui.scrimControl
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData
                                color: Ui.onScrim
                                font.family: Ui.fontText
                                font.weight: Font.Bold
                                font.pixelSize: Ui.textCaption
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        { title: "About This Game", text: page.info.about || "" },
                        { title: "Features", text: (page.info.features || []).join("  ·  ") },
                        { title: "Languages", text: (page.info.languages || []).map(x => x.trim()).join(", ") },
                        { title: "Minimum Requirements", text: page.info.requirements || "" },
                    ].filter(x => x.text)
                    delegate: FoldSection {
                        required property var modelData
                        width: col.width
                        title: modelData.title
                        text: modelData.text
                    }
                }

                GameLinks {
                    width: parent.width
                    appid: page.item.appid || 0
                    title: page.info.name || page.item.name || ""
                    website: page.info.website || ""
                    metacriticUrl: page.info.metacriticUrl || ""
                }

                MediaGallery {
                    id: mediaGallery
                    width: page.panelW
                    info: page.info
                    appRoot: page.appRoot
                    hideFirst: morph.morphing
                }
            }
        }
    }

    GalleryMorph {
        id: morph
        anchors.fill: parent
        flick: details
        wheel: detailsWheel
        gallery: mediaGallery
        view: galleryView
        button: buyButton
        active: page.open && page.wide
        motion: page.motion
        onEntered: galleryView.forceActiveFocus()
    }

    PageControls {
        anchors.fill: parent
        shown: page.open
        arrows: page.wide && page.siblings.length > 1
        opacity: page.level
        onStep: (dir) => page.step(dir)
        onClose: page.close()
    }
}
