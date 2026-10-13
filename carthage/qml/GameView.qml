// A game up close, for the library (Inspect.qml) and the store (StorePage.qml) alike: what's
// behind it (the page blurred, or the game's art), the 3D cartridge (tilt, drag to spin, flip),
// opening, closing and stepping to the next game, the details panel (where it's from, the
// title, the credits, the page's own actions and details, then the screenshots) and the
// screenshots' zoom. Each page fills in only what's its own.
//   GameView { cardGame: {…}; title: "…"; actions: [ … ]; details: [ … ] }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Effects

FocusScope {
    id: gv

    property Item appRoot
    property Item stage                  // what gets blurred behind the view
    property bool open: false
    property real level: 0               // the view's own fade
    property real panelLevel: 0          // the details' (they arrive a little after the card)
    property int panelDir: 1             // which side the details slide from: +1 the right
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property real ratio: Backend.theme.ratio
    readonly property real openDuration: 480 * motion

    // What the page shows.
    property var cardGame: ({})          // HeroCard's game
    property var info: ({})              // store details: reviews, screenshots, background…
    property string eyebrow              // where it's from ("STEAM")
    property string title
    property string credits              // developer · publisher · year (styled text, links)
    property alias eyebrowExtra: eyebrowRow.data   // beside the eyebrow (the library's FAMILY)
    property alias pinnedExtra: pinnedExtraCol.data // under the credits (the store's price)
    property alias actions: actionsRow.data        // the row of buttons
    property alias details: detailsSlot.data       // the scrolling details, before the screenshots
    property alias under: underCard.data           // under the cartridge (the store's chips)
    property Item mainButton                       // the main action (it moves into the gallery bar)
    property string gallerySubtitle
    property string detailsObjectName: ""          // (for the test harness)
    property bool showArrows: true
    property bool showDice: false
    property bool cardWheelEnabled: false          // the wheel over the card turns it (the store's offers)

    // Behind the gv. Settings → Appearance → Game View: the page blurred, or the game's art
    // on a plain dark ground (never mixed with the blur); a game with no art gets the blur.
    property string backdropUrl
    property bool detailsPending: false  // its details (and so its art) are on their way
    readonly property bool artBehind: Backend.settings.gameBackground === "backdrop" && backdropUrl !== ""
    property bool factsLate: false       // nothing came within a few seconds: no art to wait for
    readonly property bool artExpected: Backend.settings.gameBackground === "backdrop" && !Backend.fake
                                        && (artBehind || (detailsPending && !factsLate))
    function detailsLoading() {          // a new game: wait a little for its art
        factsLate = false
        factsTimer.restart()
    }
    Timer { id: factsTimer; interval: 2500; onTriggered: gv.factsLate = true }

    signal closeRequested()
    signal stepRequested(int dir)
    signal rollRequested()
    signal cardWheel(int dir)

    readonly property alias hero: heroCard
    readonly property alias backdrop: backdropItem
    readonly property alias detailsFlick: detailsFlickable
    readonly property alias detailsWheel: wheelAccel
    readonly property alias mediaGallery: media
    readonly property bool animating: openAnim.running || closeAnim.running || stepAnim.running

    // ── Layout ──
    // Wide: the cartridge at the left, the details using the rest of the width (up to a
    // readable 720), centred together. Narrow: the cartridge above the details.
    readonly property real gap: 56
    readonly property real sideM: 76  // room for the ← → keys
    readonly property bool wide: width >= 300 + gap + Ui.detailsWidth + 96
    // Wide, the cartridge gives way first: the details always get their full width.
    readonly property real heroH: wide ? Math.min(height * 0.56, 470, (width - 2 * sideM - gap - Ui.detailsWidth) * ratio)
                                       : Math.min(height * 0.42, 360)
    readonly property real heroW: Math.round(heroH / ratio)
    readonly property real panelW: wide ? Math.min(720, width - 2 * sideM - heroW - gap)
                                        : Math.min(Ui.detailsWidth, width - 64)
    readonly property real heroX: wide ? Math.max(sideM, Math.round((width - (heroW + gap + panelW)) / 2))
                                       : Math.round((width - heroW) / 2)
    // Wide: the cartridge is centred; the title keeps its own height near the top, its
    // capitals level with the cartridge's top at most.
    readonly property real heroY: wide ? Math.round((height - heroH) / 2) : 28
    readonly property real titleY: wide ? Math.round(Math.min((height - heroH) / 2, 72 + detailsPanel.titleLift)) : 28
    // Once the cartridge has arrived it follows its place (the window resized, the group
    // re-centred).
    readonly property bool settled: open && !openAnim.running && !closeAnim.running && !stepAnim.running
                                    && !settleAnim.running && !flipAnim.running
    onHeroXChanged: if (settled) follow.restart()
    onHeroYChanged: if (settled) follow.restart()
    ParallelAnimation {
        id: follow
        NumberAnimation { target: heroCard; property: "x"; to: gv.heroX; duration: 200 * gv.motion; easing.type: Easing.OutCubic }
        NumberAnimation { target: heroCard; property: "y"; to: gv.heroY; duration: 200 * gv.motion; easing.type: Easing.OutCubic }
    }

    visible: level > 0.001 || open || closeAnim.running || warming

    // The 3D card's first frame takes ~160 ms to set up (renderer, textures): a page that sets
    // warmUp does it once, invisibly, after startup, so the first real opening doesn't hitch.
    property bool warmUp: false
    property bool warming: false
    Timer {
        running: gv.warmUp
        interval: 1200
        onTriggered: { gv.warming = true; warmEnd.start() }
    }
    Timer { id: warmEnd; interval: 600; onTriggered: gv.warming = false }

    // ── Opening, closing, stepping ──
    // The second click of a double-click lands on the backdrop of the view the first one just
    // opened: it mustn't close it again.
    property double openedAt: 0
    // Opens with the card flying from (x, y) at `scale` (top-left origin) to its place.
    function flyIn(x, y, scale) {
        openedAt = Date.now()
        closeAnim.stop()
        heroCard.x = x
        heroCard.y = y
        heroCard.scale = scale
        heroCard.opacity = 1
        heroCard.spin = 0
        heroCard.dragTilt = 0
        heroCard.visible = true
        panelDir = 1
        open = true
        resetGallery()
        detailsFlickable.contentY = 0
        if (mainButton) mainButton.forceActiveFocus()
        else forceActiveFocus()
        if (motion <= 0) {
            heroCard.x = heroX; heroCard.y = heroY; heroCard.scale = 1; level = 1; panelLevel = 1
            return
        }
        openAnim.restart()
    }
    // Closes with the card going to (x, y, scale, opacity); `done` once it's there.
    function flyOut(x, y, scale, opacity, done) {
        if (!open) return
        stepAnim.complete()
        resetGallery()
        panelDir = 1
        settleAnim.stop()
        flipAnim.stop()
        heroCard.dragTilt = 0
        open = false
        openAnim.stop()
        closeAnim.toX = x
        closeAnim.toY = y
        closeAnim.toScale = scale
        closeAnim.toOpacity = opacity
        closeAnim.toSpin = Math.round(heroCard.spin / 360) * 360
        closeAnim.done = done || null
        if (motion <= 0) { finishClose(); return }
        closeAnim.restart()
    }
    function finishClose() {
        heroCard.visible = false
        level = 0
        panelLevel = 0
        if (closeAnim.done) closeAnim.done()
        closeAnim.done = null
    }
    // Gone without the card flying anywhere (it went into the dock).
    function dismiss() {
        open = false
        openAnim.stop()
        heroCard.visible = false
        if (motion <= 0) { level = 0; panelLevel = 0 } else dismissAnim.restart()
    }
    // To the next game: the card slides out one way and the next slides in, the details
    // following; `swap` changes the game halfway.
    function stepTo(dir, swap) {
        settleAnim.stop()
        flipAnim.stop()
        heroCard.dragTilt = 0
        appRoot.sound("hover")
        stepAnim.dir = dir
        stepAnim.swap = swap
        panelDir = -dir
        if (motion <= 0) { swap(); afterSwap(); return }
        stepAnim.restart()
    }
    function afterSwap() {
        heroCard.spin = 0
        resetGallery()
        detailsFlickable.contentY = 0
    }
    function nudge() { if (motion > 0) edgeNudge.restart() }

    function settle(velocityX) {
        const coast = heroCard.spin + Math.max(-540, Math.min(540, velocityX * 0.25))
        settleAnim.spinTo = Math.round(coast / 180) * 180
        if (motion <= 0) { heroCard.spin = settleAnim.spinTo; heroCard.dragTilt = 0; return }
        settleAnim.restart()
        if (Math.abs(settleAnim.spinTo - heroCard.spin) >= 90) appRoot.sound("hover")
    }
    function flip() {
        if (!open) return
        const target = Math.round(heroCard.spin / 180) * 180 + 180
        if (motion <= 0) { heroCard.spin = target % 360; return }
        flipAnim.to = target
        flipAnim.restart()
        appRoot.sound("hover")
    }
    function stopTurning() { settleAnim.stop(); flipAnim.stop(); heroCard.dragTilt = 0 }
    readonly property bool turning: flipAnim.running || settleAnim.running

    Keys.onEscapePressed: closeRequested()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F && open) {
            flip()
            event.accepted = true
        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && open) {
            stepRequested(event.key === Qt.Key_Left ? -1 : 1)
            event.accepted = true
        }
    }

    // ── Behind ──
    ShaderEffectSource {
        id: stageSource
        sourceItem: gv.stage
        sourceRect: Qt.rect(gv.x, gv.y, gv.width, gv.height)  // the part behind
        // Frozen while the view is open (cartridges coming and going behind would show
        // through); live while it opens and closes.
        live: gv.visible && (!gv.open || openAnim.running || closeAnim.running)
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: stageSource
        visible: gv.level > 0.001 && !gv.artExpected
        opacity: gv.level
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle {  // a plain dark ground while the art is on its way (never the blur first)
        anchors.fill: parent
        visible: gv.artExpected
        color: "#0b0b0e"
        opacity: gv.level
    }
    // The game's art under the scrim (at most 55%: white text stays ≥4.5:1 over any art).
    GameBackdrop {
        id: backdropItem
        anchors.fill: parent
        level: gv.level * 0.55 * (1 - gv.galleryLevel)  // (it cross-fades its own art)
        source: gv.artBehind ? gv.backdropUrl : ""
    }
    Rectangle {  // dark enough for the white text in both editions (≥4.5:1)
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.05, Backend.theme.dark ? 0.72 : 0.64)
        opacity: gv.level
    }
    MouseArea {
        anchors.fill: parent
        enabled: gv.open
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: if (Date.now() - gv.openedAt > 450) gv.closeRequested()
        onWheel: (wheel) => wheel.accepted = true
    }

    // ── The cartridge ──
    HeroCard {
        id: heroCard
        visible: false || gv.warming
        opacity: gv.warming && !gv.open ? 0.004 : 1
        // Warming up it's an invisible card in the top-left corner: it mustn't take the clicks
        // meant for what's under it.
        enabled: !gv.warming || gv.open
        width: gv.heroW
        height: gv.heroW * gv.ratio
        transformOrigin: Item.TopLeft
        transform: Translate { x: -gv.zoomShift }
        game: gv.cardGame
        motion: gv.motion
        holding: gv.open
        busy: openAnim.running || flipAnim.running || settleAnim.running || stepAnim.running
        selfSettling: false
        onReleased: (vx) => gv.settle(vx)
        onTapped: gv.galleryMode ? gv.exitGallery() : gv.flip()
        onDraggingChanged: if (dragging) { flipAnim.stop(); settleAnim.stop() }
        WheelHandler {
            enabled: gv.cardWheelEnabled && !gv.galleryMode
            property real acc: 0
            onWheel: (ev) => {
                acc += ev.angleDelta.y || ev.angleDelta.x
                if (Math.abs(acc) >= 120) {
                    gv.cardWheel(acc < 0 ? 1 : -1)
                    acc = 0
                }
            }
        }
    }
    Item {  // under the cartridge (wide only): the page's own (the store's chips)
        id: underCard
        visible: gv.wide
        x: gv.heroX - gv.zoomShift
        y: gv.heroY + gv.heroH + Ui.gapL
        width: gv.heroW
        height: childrenRect.height
        opacity: gv.level * (1 - gv.galleryLevel)
        enabled: gv.open && !gv.galleryMode
    }

    ParallelAnimation {
        id: settleAnim
        property real spinTo: 0
        NumberAnimation {
            target: heroCard
            property: "spin"
            to: settleAnim.spinTo
            duration: Math.min(900, 260 + Math.abs(settleAnim.spinTo - heroCard.spin) * 1.1) * gv.motion
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
        NumberAnimation { target: heroCard; property: "dragTilt"; to: 0; duration: 380 * gv.motion; easing.type: Easing.OutBack }
        onFinished: heroCard.spin = ((heroCard.spin % 360) + 360) % 360
    }
    NumberAnimation {
        id: flipAnim
        target: heroCard
        property: "spin"
        duration: 460 * gv.motion
        easing.type: Easing.OutBack
        easing.overshoot: 0.8
        onFinished: heroCard.spin = heroCard.spin % 360
    }
    ParallelAnimation {
        id: openAnim
        // Flight and spin share one duration and easing, so the card finishes its turn as it
        // arrives.
        NumberAnimation { target: heroCard; property: "x"; to: gv.heroX; duration: gv.openDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: heroCard; property: "y"; to: gv.heroY; duration: gv.openDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: heroCard; property: "scale"; to: 1; duration: gv.openDuration; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: heroCard; property: "spin"; from: 0; to: 360; duration: gv.openDuration; easing.type: Easing.OutCubic }
            ScriptAction { script: heroCard.spin = 0 }
        }
        NumberAnimation { target: gv; property: "level"; to: 1; duration: 220 * gv.motion; easing.type: Easing.OutQuad }
        SequentialAnimation {
            // The details wait until the flying card has crossed their side (its back passed
            // over the title).
            PauseAnimation { duration: gv.openDuration * 0.4 }
            NumberAnimation { target: gv; property: "panelLevel"; to: 1; duration: 240 * gv.motion; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: closeAnim
        property real toX
        property real toY
        property real toScale
        property real toOpacity: 1
        property real toSpin: 0
        property var done: null
        ParallelAnimation {
            // The "place" sound's thump is ~125 ms in.
            SequentialAnimation {
                PauseAnimation { duration: Math.max(0, 300 * gv.motion - 125) }
                ScriptAction { script: if (closeAnim.toOpacity > 0) gv.appRoot.sound("place") }
            }
            NumberAnimation { target: heroCard; property: "spin"; to: closeAnim.toSpin; duration: 300 * gv.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: heroCard; property: "x"; to: closeAnim.toX; duration: 300 * gv.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: heroCard; property: "y"; to: closeAnim.toY; duration: 300 * gv.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: heroCard; property: "scale"; to: closeAnim.toScale; duration: 300 * gv.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: heroCard; property: "opacity"; to: closeAnim.toOpacity; duration: 300 * gv.motion }
            NumberAnimation { target: gv; property: "level"; to: 0; duration: 240 * gv.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: gv; property: "panelLevel"; to: 0; duration: 120 * gv.motion; easing.type: Easing.InQuad }
        }
        ScriptAction { script: gv.finishClose() }
    }
    ParallelAnimation {
        id: dismissAnim
        NumberAnimation { target: gv; property: "level"; to: 0; duration: 260 * gv.motion; easing.type: Easing.InQuad }
        NumberAnimation { target: gv; property: "panelLevel"; to: 0; duration: 140 * gv.motion; easing.type: Easing.InQuad }
    }
    SequentialAnimation {
        id: stepAnim
        property int dir: 1
        property var swap: null
        readonly property real shift: gv.heroW * 0.35
        ParallelAnimation {
            NumberAnimation { target: heroCard; property: "x"; to: gv.heroX - stepAnim.dir * stepAnim.shift; duration: 150 * gv.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: heroCard; property: "opacity"; to: 0; duration: 150 * gv.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: gv; property: "panelLevel"; to: 0; duration: 120 * gv.motion; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                if (stepAnim.swap) stepAnim.swap()
                gv.afterSwap()
                heroCard.x = gv.heroX + stepAnim.dir * stepAnim.shift
                gv.panelDir = stepAnim.dir
            }
        }
        ParallelAnimation {
            NumberAnimation { target: heroCard; property: "x"; to: gv.heroX; duration: 220 * gv.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: heroCard; property: "opacity"; to: 1; duration: 180 * gv.motion; easing.type: Easing.OutQuad }
            NumberAnimation { target: gv; property: "panelLevel"; to: 1; duration: 220 * gv.motion; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: edgeNudge
        NumberAnimation { target: heroCard; property: "x"; to: gv.heroX - 6; duration: 50 * gv.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: heroCard; property: "x"; to: gv.heroX + 6; duration: 70 * gv.motion; easing.type: Easing.InOutQuad }
        NumberAnimation { target: heroCard; property: "x"; to: gv.heroX; duration: 50 * gv.motion; easing.type: Easing.InQuad }
    }

    // ── The gallery (a screenshot clicked) ──
    readonly property real peekW: 64
    readonly property real panelBaseX: wide ? heroX + heroW + gap : Math.round((width - panelW) / 2)
    readonly property real panelGalleryX: peekW + gap
    readonly property bool galleryMode: morph.galleryMode
    readonly property bool standIn: morph.standIn  // the main button's stand-in is moving (hide the real one)
    readonly property real galleryLevel: morph.level
    // How far the cartridge has moved left (into the gallery).
    readonly property real zoomShift: galleryLevel * (heroX + heroW - peekW)
    function resetGallery() { morph.reset() }  // no animation: closing or showing another game
    function exitGallery() {
        morph.exit()
        if (mainButton) mainButton.forceActiveFocus()
        else forceActiveFocus()
    }

    GalleryView {
        id: galleryView
        x: gv.panelGalleryX + (1 - gv.galleryLevel) * 40
        y: Ui.gapXL
        width: gv.width - gv.panelGalleryX - 72
        height: gv.height - 2 * Ui.gapXL
        opacity: gv.panelLevel * morph.galleryOpacity
        visible: opacity > 0.01 || morph.morphing
        enabled: gv.galleryMode
        morphing: morph.standIn
        info: gv.info
        appRoot: gv.appRoot
        title: gv.title
        subtitle: gv.gallerySubtitle
        actionText: gv.mainButton ? gv.mainButton.text : ""
        actionIcon: gv.mainButton ? gv.mainButton.icon.name : ""
        actionEnabled: gv.mainButton ? gv.mainButton.enabled : false
        onAction: {
            gv.resetGallery()
            if (gv.mainButton) gv.mainButton.clicked()
        }
        onBack: gv.exitGallery()
    }

    // ── The details ──
    Item {
        id: detailsPanel
        readonly property real avail: gv.wide ? gv.height - gv.titleY - Ui.gapXL
                                                : gv.height - (gv.heroY + gv.heroH + 28) - 20
        x: gv.panelBaseX - gv.galleryLevel * 40
        // The title's capitals line up with the cartridge's top edge; where it's from hangs
        // above. It stays there while the details arrive (Play mustn't move under the pointer).
        readonly property real titleLift: Math.round(eyebrowRow.height + Ui.gapS + titleText.y0)
        y: gv.wide ? gv.titleY - titleLift : gv.heroY + gv.heroH + 28
        Behavior on y {
            enabled: gv.settled
            NumberAnimation { duration: 200 * gv.motion; easing.type: Easing.OutCubic }
        }
        width: detailsFlickable.width
        height: pinned.height + Ui.gapXL + detailsFlickable.height
        opacity: gv.panelLevel * morph.detailsOpacity
        enabled: !gv.galleryMode
        visible: opacity > 0.01 || morph.morphing
        transform: Translate { x: (1 - gv.panelLevel) * 28 * gv.panelDir }
        Accessible.role: Accessible.Dialog
        Accessible.name: gv.title

        Column {
            id: pinned
            width: gv.panelW
            spacing: Ui.gapXL
            Column {
                width: parent.width
                spacing: Ui.gapS
                Row {
                    id: eyebrowRow
                    spacing: Ui.gapM
                    Text {
                        text: gv.eyebrow.toUpperCase()
                        color: Ui.onScrimDim
                        font.family: Ui.fontLabels
                        font.weight: Font.Black
                        font.pixelSize: Ui.textBody
                        font.letterSpacing: 2.5
                    }
                }
                Text {
                    id: titleText
                    // From the top of the text box to the top of the capitals (an H's real
                    // outline: the font's declared cap height was 3 px off).
                    readonly property real y0: Math.max(0, titleText.baselineOffset + titleFm.tightBoundingRect("H").y)
                    FontMetrics { id: titleFm; font: titleText.font }
                    width: parent.width
                    text: gv.title
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
                    topPadding: 2
                    textFormat: Text.StyledText
                    text: gv.credits
                    linkColor: Ui.onScrimDim
                    onLinkActivated: (url) => Backend.openUrl(url)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    color: Ui.onScrimDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textLead
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            Column {
                id: pinnedExtraCol
                width: parent.width
                spacing: Ui.gapM
                visible: children.length > 0
            }
            Row {
                id: actionsRow
                width: parent.width
                spacing: Ui.gapM
            }
        }

        Flickable {
            id: detailsFlickable
            objectName: gv.detailsObjectName
            y: pinned.height + Ui.gapXL
            width: gv.panelW + (contentHeight > height ? Ui.gapL : 0)
            height: Math.max(0, Math.min(detailsCol.height, detailsPanel.avail - pinned.height - Ui.gapXL))
            contentHeight: Math.max(detailsCol.height, morph.neededContentHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelAccel { id: wheelAccel; flickable: detailsFlickable; step: 90 }
            AutoScroll { flickable: detailsFlickable }
            onVisibleChanged: if (visible) contentY = 0
            QQC2.ScrollBar.vertical: CScrollBar { onDark: true }

            Column {
                id: detailsCol
                width: gv.panelW
                spacing: Ui.gapXL
                Column {
                    id: detailsSlot
                    width: parent.width
                    spacing: Ui.gapXL
                }
                MediaGallery {
                    id: media
                    width: gv.panelW
                    info: gv.info
                    appRoot: gv.appRoot
                    hideFirst: morph.standIn
                }
            }
        }
    }

    GalleryMorph {
        id: morph
        anchors.fill: parent
        flick: detailsFlickable
        wheel: wheelAccel
        gallery: media
        view: galleryView
        button: gv.mainButton
        // Scrolling on once the screenshots reach the top turns the view into its gallery (as
        // before; it springs in or out, never resting halfway).
        active: gv.open && gv.wide
        motion: gv.motion
        onEntered: galleryView.forceActiveFocus()
    }

    PageControls {
        arrowY: gv.wide ? heroCard.y + heroCard.height * heroCard.scale / 2 : -1
        anchors.fill: parent
        z: 1
        shown: gv.open
        arrows: gv.wide && gv.showArrows
        dice: gv.showDice
        // It fades away as the screenshots grow into the full view, and back as they shrink.
        diceLevel: 1 - gv.galleryLevel
        opacity: gv.level  // (not the panel's: they stay put while stepping)
        onStep: (dir) => gv.stepRequested(dir)
        onClose: gv.closeRequested()
        onRoll: gv.rollRequested()
    }
}
