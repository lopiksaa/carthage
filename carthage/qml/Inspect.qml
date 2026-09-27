// The closer look: choosing a card lifts it out of the tray into the middle of the window,
// larger, next to its details and a big Play button. It doubles as the confirmation step,
// so a stray click never launches a game. Esc, the close button or a click on the
// backdrop puts the card back.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Effects

FocusScope {
    id: inspect

    property Item appRoot
    property Item stage // what gets blurred behind the view

    property bool open: false
    property var game: ({})
    readonly property var pal: Backend.theme.p
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property real ratio: Backend.theme.ratio
    readonly property real openDuration: 480 * motion

    // 0 → 1 as the view opens; drives the backdrop and the details panel.
    property real level: 0
    property real panelLevel: 0
    // Which side the details slide from/to: +1 the right (opening), and while stepping
    // between games the same way the card goes.
    property int panelDir: 1

    // Store facts for the game on show (Steam games): reviews, screenshots, About… from
    // store.py, plus how many are playing right now.
    property var info: ({})
    property var extras: ({})
    function loadFacts() {
        info = {}
        extras = {}
        if (Backend.fake || !game.gameId || game.source === "carthage") return
        const appid = game.source === "steam" ? parseInt(game.extId) || 0 : 0
        if (appid) Backend.store.loadDetailsQuiet(appid)
        Backend.store.loadExtras(game.gameId, appid, game.title || "")
    }
    Connections {
        target: Backend.store
        function onDetailsReady(appid, data) {
            if (inspect.game.source === "steam" && appid === (parseInt(inspect.game.extId) || -1)) inspect.info = data
        }
        function onExtrasReady(key, data) {
            if (key === inspect.game.gameId) inspect.extras = data
        }
    }

    // Layout: card left, details right; stacked when the window is narrow.
    readonly property real panelW: Math.min(Ui.detailsWidth, width - 64)
    readonly property real gap: 56
    readonly property bool wide: width >= 300 + gap + panelW + 96
    readonly property real heroH: wide ? Math.min(height * 0.72, 560) : Math.min(height * 0.42, 360)
    readonly property real heroW: Math.round(heroH / ratio)
    readonly property real heroX: wide ? Math.round((width - (heroW + gap + panelW)) / 2) : Math.round((width - heroW) / 2)
    readonly property real heroY: wide ? Math.round((height - heroH) / 2) : 28

    visible: level > 0.001 || open || closeAnim.running || warming

    // The 3D card's first frame takes ~160 ms to set up (renderer, textures). Do it once,
    // invisibly, shortly after startup, so the first real opening doesn't hitch.
    property bool warming: false
    Timer {
        running: true
        interval: 1200
        onTriggered: {
            inspect.warming = true
            warmEnd.start()
        }
    }
    Timer {
        id: warmEnd
        interval: 600
        onTriggered: inspect.warming = false
    }

    function lastPlayedText(ts) {
        if (!ts) return "Never played"
        const days = Math.floor((Date.now() / 1000 - ts) / 86400)
        if (days < 1) return "Played today"
        if (days === 1) return "Played yesterday"
        if (days < 30) return "Played " + days + " days ago"
        const months = Math.floor(days / 30)
        return "Played " + months + (months === 1 ? " month ago" : " months ago")
    }

    function playtimeText(minutes) {
        if (!minutes) return ""
        if (minutes < 60) return minutes + (minutes === 1 ? " minute played" : " minutes played")
        const h = Math.round(minutes / 6) / 10
        return (h >= 10 ? Math.round(h) : h) + (h === 1 ? " hour played" : " hours played")
    }

    // The game object is a snapshot taken when the view opens. An install that finishes
    // while it's open reloads the library; pick up the new state so Play appears right away.
    function refreshInstalled() {
        if (!open || !game.gameId) return
        const now = Backend.isInstalled(game.gameId)
        if (now !== (game.installed !== false)) {
            const g = Object.assign({}, game)
            g.installed = now
            game = g
        }
    }
    Connections {
        target: Backend.games
        function onModelReset() { inspect.refreshInstalled() }
        function onDataChanged() { inspect.refreshInstalled() }
    }

    function openFor(cell) {
        if (open) return
        // Build the whole object before assigning it: bindings only see a new `game`, not
        // later changes to its fields (that's why "Never played" showed for played games).
        const g = appRoot.cardData(cell)
        g.lastPlayed = cell.lastPlayed
        g.playtime = cell.playtime
        g.developer = cell.developer
        g.publisher = cell.publisher
        g.released = cell.released
        game = g
        loadFacts()

        // Start exactly where the (possibly lifted) card is.
        const s0 = 1 + 0.05 * cell.lift
        const base = cell.mapToItem(inspect, cell.cardX, cell.cardY - cell.cardW * 0.035 * cell.lift)
        hero.x = base.x + cell.cardW * (1 - s0) / 2
        hero.y = base.y + cell.cardH * (1 - s0) / 2
        hero.scale = s0 * cell.cardW / heroW
        hero.opacity = 1
        hero.spin = 0
        hero.visible = true
        appRoot.setHidden(game.gameId, true)
        open = true
        appRoot.sound("pick")
        playButton.forceActiveFocus()

        closeAnim.stop()
        panelDir = 1
        if (motion <= 0) {
            hero.x = heroX; hero.y = heroY; hero.scale = 1; level = 1; panelLevel = 1
            return
        }
        openAnim.restart()
    }

    // ← →: the previous / next game in the tray's order (games in the dock are skipped).
    // The card slides out, the next one slides in, and the tray scrolls along so closing
    // still flies the card back into the right pocket.
    function step(dir) {
        if (!open || openAnim.running || closeAnim.running || stepAnim.running || rolling) return
        let row = Backend.games.rowOf(game.gameId)
        let gid = ""
        for (let r = row + dir; r >= 0 && r < Backend.games.count; r += dir) {
            const id = Backend.games.idAt(r)
            if (Backend.sessions.indexOf(id) < 0) { gid = id; break }
        }
        if (!gid) {
            if (motion > 0) edgeNudge.restart()
            return
        }
        otherMenu.close()
        settleAnim.stop()
        flipAnim.stop()
        hero.dragTilt = 0
        appRoot.sound("hover")
        stepAnim.dir = dir
        stepAnim.next = Backend.gameInfo(gid)
        panelDir = -dir
        if (motion <= 0) { swapTo(stepAnim.next); return }
        stepAnim.restart()
    }
    function swapTo(data) {
        appRoot.setHidden(game.gameId, false)
        game = data
        appRoot.setHidden(game.gameId, true)
        appRoot.revealInTray(game.gameId)
        loadFacts()
        hero.spin = 0
        resetGallery()
        detailsFlick.contentY = 0
    }
    SequentialAnimation {
        id: stepAnim
        property int dir: 1
        property var next: ({})
        readonly property real shift: inspect.heroW * 0.35
        ParallelAnimation {
            NumberAnimation { target: hero; property: "x"; to: inspect.heroX - stepAnim.dir * stepAnim.shift; duration: 150 * inspect.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: hero; property: "opacity"; to: 0; duration: 150 * inspect.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: inspect; property: "panelLevel"; to: 0; duration: 120 * inspect.motion; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                inspect.swapTo(stepAnim.next)
                hero.x = inspect.heroX + stepAnim.dir * stepAnim.shift
                inspect.panelDir = stepAnim.dir
            }
        }
        ParallelAnimation {
            NumberAnimation { target: hero; property: "x"; to: inspect.heroX; duration: 220 * inspect.motion; easing.type: Easing.OutCubic }
            NumberAnimation { target: hero; property: "opacity"; to: 1; duration: 180 * inspect.motion; easing.type: Easing.OutQuad }
            NumberAnimation { target: inspect; property: "panelLevel"; to: 1; duration: 220 * inspect.motion; easing.type: Easing.OutCubic }
        }
    }
    // The dice, from here (App.rollDice): the cartridge turns over and over, a different
    // game coming round each time, slower and slower until it stops on the pick.
    property bool rolling: false
    property var rollFaces: []
    function rollTo(gid, pool) {
        if (!open || openAnim.running || closeAnim.running || stepAnim.running || rolling) return
        otherMenu.close()
        settleAnim.stop()
        flipAnim.stop()
        hero.dragTilt = 0
        panelDir = 1
        if (motion <= 0) {
            swapTo(Backend.gameInfo(gid))
            return
        }
        const others = pool.filter(id => id !== gid)
        const faces = []
        for (let i = 0; i < 4 && others.length; i++) {
            let f = others[Math.floor(Math.random() * others.length)]
            if (others.length > 1 && f === faces[i - 1]) f = others[(others.indexOf(f) + 1) % others.length]
            faces.push(f)
        }
        rollFaces = faces.concat([gid])
        rolling = true
        // The card it started from goes back into its recess while the others spin past.
        appRoot.setHidden(game.gameId, false)
        rollOut.restart()
    }
    function rollNext() {
        if (!rolling) return
        const id = rollFaces.shift()
        turnAnim.next = id
        turnAnim.last = rollFaces.length === 0
        turnAnim.q = turnAnim.last ? 170 : 55 + 20 * (4 - rollFaces.length)
        turnAnim.restart()
    }
    NumberAnimation {
        id: rollOut
        target: inspect; property: "panelLevel"; to: 0
        duration: 120 * inspect.motion; easing.type: Easing.InQuad
        onFinished: inspect.rollNext()
    }
    SequentialAnimation {
        id: turnAnim
        property string next
        property bool last: false
        property real q: 60
        NumberAnimation { target: hero; property: "spin"; from: 0; to: 90; duration: turnAnim.q * inspect.motion; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                const g = Backend.gameInfo(turnAnim.next)
                if (turnAnim.last) inspect.swapTo(g)
                else inspect.game = g
                inspect.appRoot.sound("hover")
            }
        }
        NumberAnimation {
            target: hero; property: "spin"; from: -90; to: 0
            duration: turnAnim.q * (turnAnim.last ? 2.4 : 1) * inspect.motion
            easing.type: turnAnim.last ? Easing.OutBack : Easing.OutQuad
        }
        ScriptAction {
            script: {
                if (turnAnim.last) {
                    inspect.rolling = false
                    rollIn.restart()
                } else {
                    Qt.callLater(inspect.rollNext)
                }
            }
        }
    }
    NumberAnimation {
        id: rollIn
        target: inspect; property: "panelLevel"; to: 1
        duration: 220 * inspect.motion; easing.type: Easing.OutCubic
    }

    // Nothing further that way: a small shake, like a cartridge bumping the tray's edge.
    SequentialAnimation {
        id: edgeNudge
        NumberAnimation { target: hero; property: "x"; to: inspect.heroX - 6; duration: 50 }
        NumberAnimation { target: hero; property: "x"; to: inspect.heroX + 6; duration: 70 }
        NumberAnimation { target: hero; property: "x"; to: inspect.heroX; duration: 50 }
    }

    function resetGallery() { morph.reset() }  // no animation: closing or showing another game

    function close() {
        if (!open) return
        stepAnim.complete()
        if (rolling) {
            rolling = false
            rollOut.stop()
            turnAnim.stop()
        }
        resetGallery()
        panelDir = 1
        otherMenu.close()
        settleAnim.stop()
        hero.dragTilt = 0
        open = false
        openAnim.stop()
        const cell = appRoot.cellFor(game.gameId)
        const visibleCell = cell && appRoot.isCellVisible(cell)
        if (visibleCell) {
            const t = cell.mapToItem(inspect, cell.cardX, cell.cardY)
            closeAnim.toX = t.x
            closeAnim.toY = t.y
            closeAnim.toScale = cell.cardW / heroW
            closeAnim.toOpacity = 1
            closeAnim.toSpin = Math.round(hero.spin / 360) * 360
        } else {
            closeAnim.toSpin = Math.round(hero.spin / 360) * 360
            closeAnim.toX = hero.x
            closeAnim.toY = hero.y + 40
            closeAnim.toScale = hero.scale * 0.9
            closeAnim.toOpacity = 0
        }
        if (motion <= 0) {
            finishClose()
            return
        }
        closeAnim.restart()
    }

    function finishClose() {
        hero.visible = false
        level = 0
        panelLevel = 0
        appRoot.setHidden(game.gameId, false)
        appRoot.focusTray()
    }

    // After a drag: carry on a bit in the flick's direction, then rest face-on.
    function settle(velocityX) {
        const coast = hero.spin + Math.max(-540, Math.min(540, velocityX * 0.25))
        settleAnim.spinTo = Math.round(coast / 180) * 180
        if (motion <= 0) {
            hero.spin = settleAnim.spinTo
            hero.dragTilt = 0
            return
        }
        settleAnim.restart()
        if (Math.abs(settleAnim.spinTo - hero.spin) >= 90) appRoot.sound("hover")
    }

    function closeMenus() { otherMenu.close() }  // demo harness
    function scrollDetails(y) { detailsFlick.contentY = y }  // demo harness
    function openOther() {  // demo harness
        otherMenu.popup(otherButton, 0, otherButton.height + 6)
    }

    function flip() {
        if (!open) return
        const target = Math.round(hero.spin / 180) * 180 + 180
        if (motion <= 0) { hero.spin = target % 360; return }
        flipAnim.to = target
        flipAnim.restart()
        appRoot.sound("hover")
    }

    function play() {
        if (!open) return
        settleAnim.stop()
        hero.dragTilt = 0
        if (hero.showingBack || flipAnim.running) {
            // Turn back to the front first, then fly.
            flipAnim.stop()
            frontThenPlay.restart()
            return
        }
        const result = appRoot.play(game, {
            x: hero.x, y: hero.y, scale: hero.scale, cardWidth: heroW, lift: 1,
        }, function () { heroPress.restart() })
        if (result === "slot") {
            // The flight takes over from here; the backdrop and details fade away.
            open = false
            openAnim.stop()
            hero.visible = false
            appRoot.focusTray()
            if (motion <= 0) { level = 0; panelLevel = 0 } else dismissAnim.restart()
        } else if (result === "noslot" || result === "running") {
            close()
        }
    }

    Keys.onEscapePressed: close()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F && open) {
            flip()
            event.accepted = true
        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && open) {
            step(event.key === Qt.Key_Left ? -1 : 1)
            event.accepted = true
        }
    }

    // ------------------------------------------------------------ backdrop

    ShaderEffectSource {
        id: stageSource
        sourceItem: inspect.stage
        live: inspect.visible
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: stageSource
        visible: inspect.level > 0.001
        opacity: inspect.level
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        autoPaddingEnabled: false
    }
    // Dark enough in both editions that the white details text stays readable (≥4.5:1).
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.05, Backend.theme.dark ? 0.72 : 0.64)
        opacity: inspect.level
    }
    // Swallows everything behind the view while it's open; a click on the backdrop closes it.
    MouseArea {
        anchors.fill: parent
        enabled: inspect.open
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: inspect.close()
        onWheel: (wheel) => wheel.accepted = true
    }

    // ------------------------------------------------------------ the card

    Item {
        id: hero
        visible: false || inspect.warming
        // While warming up: rendered but not seen (almost fully transparent, no input).
        opacity: inspect.warming && !inspect.open ? 0.004 : 1
        width: inspect.heroW
        height: inspect.heroW * inspect.ratio
        transformOrigin: Item.TopLeft
        // Gallery mode: slides off to the left until only a strip still shows.
        transform: Translate { x: -inspect.galleryLevel * (inspect.heroX + inspect.heroW - inspect.peekW) }

        readonly property bool tilting: heroHover.hovered && !spinDrag.active && inspect.open
                                        && Backend.settings.tiltEnabled && inspect.motion > 0
        property real dragTilt: 0 // forward/back tip while being dragged

        readonly property bool idle: inspect.open && !openAnim.running && !flipAnim.running
                                     && !settleAnim.running && !spinDrag.active && !heroHover.hovered
        IdleDrift {
            id: drift
            active: hero.idle
            motion: inspect.motion
        }
        property real tiltX: tilting ? -(heroHover.point.position.y / height - 0.5) * 2 * 7 : 0
        property real tiltY: tilting ? (heroHover.point.position.x / width - 0.5) * 2 * 7 : 0
        Behavior on tiltX { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }
        Behavior on tiltY { SpringAnimation { spring: 4; damping: 0.55; epsilon: 0.05 } }
        property real press: 1
        property real spin: 0 // degrees around the vertical axis; 180 shows the back
        readonly property bool showingBack: Math.cos(spin * Math.PI / 180) < 0

        // Held up close: a large, soft shadow.
        Image {
            readonly property real sp: hero.width * 0.16
            x: -sp + hero.width * 0.05
            y: -sp + hero.width * 0.09
            width: hero.width + 2 * sp
            height: hero.height + 2 * sp
            // The card's shadow on the backdrop: it narrows as the card turns and fades out
            // as it goes edge-on (a sideways card casts almost no shadow toward the viewer).
            readonly property real face: Math.abs(Math.cos(hero.spin * Math.PI / 180))
                                       * Math.abs(Math.cos((hero.tiltX + hero.dragTilt) * Math.PI / 180))
            opacity: inspect.pal.shadowStrength * 0.8 * Math.pow(face, 1.5)
            visible: opacity > 0.01
            transform: Scale {
                origin.x: hero.width / 2 + hero.width * 0.16
                origin.y: hero.height / 2 + hero.width * 0.16
                xScale: Math.max(0.05, Math.abs(Math.cos(hero.spin * Math.PI / 180)))
                yScale: Math.max(0.3, Math.abs(Math.cos((hero.tiltX + hero.dragTilt) * Math.PI / 180)))
            }
            source: "image://gc/shadow/" + Backend.theme.edition
            sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
        }

        // The real 3D card (front, back and a lit edge). Its view is larger than the card
        // so the corners have room while it turns.
        Card3D {
            id: card3d
            anchors.centerIn: parent
            width: hero.width * 2.1
            height: hero.height * 1.35
            cardHeight: hero.height
            game: inspect.game
            anchors.verticalCenterOffset: drift.float
            spin: hero.spin + drift.turn
            tiltX: hero.tiltX + hero.dragTilt + drift.tip
            tiltY: hero.tiltY
            scale: hero.press
        }

        HoverHandler {
            id: heroHover
            cursorShape: spinDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
        // Grab and spin: sideways turns it around, up/down tips it. On release it keeps a
        // little momentum and settles on the nearest face.
        DragHandler {
            id: spinDrag
            target: null
            enabled: inspect.open
            property real startSpin: 0
            onActiveChanged: {
                if (active) {
                    flipAnim.stop()
                    settleAnim.stop()
                    startSpin = hero.spin
                } else {
                    inspect.settle(centroid.velocity.x)
                }
            }
            onTranslationChanged: {
                if (!active) return
                hero.spin = startSpin + translation.x * 0.55
                hero.dragTilt = Math.max(-30, Math.min(30, -translation.y * 0.25))
            }
        }
        // Choosing the card turns it over.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: inspect.galleryMode ? inspect.exitGallery() : inspect.flip()
        }

    }

    ParallelAnimation {
        id: settleAnim
        property real spinTo: 0
        NumberAnimation {
            target: hero
            property: "spin"
            to: settleAnim.spinTo
            duration: Math.min(900, 260 + Math.abs(settleAnim.spinTo - hero.spin) * 1.1) * inspect.motion
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
        NumberAnimation { target: hero; property: "dragTilt"; to: 0; duration: 380 * inspect.motion; easing.type: Easing.OutBack }
        onFinished: hero.spin = ((hero.spin % 360) + 360) % 360
    }

    NumberAnimation {
        id: flipAnim
        target: hero
        property: "spin"
        duration: 460 * inspect.motion
        easing.type: Easing.OutBack
        easing.overshoot: 0.8
        onFinished: hero.spin = hero.spin % 360
    }
    SequentialAnimation {
        id: frontThenPlay
        NumberAnimation {
            target: hero
            property: "spin"
            to: Math.ceil(hero.spin / 360) * 360
            duration: 260 * inspect.motion
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                hero.spin = 0
                inspect.play()
            }
        }
    }

    SequentialAnimation {
        id: heroPress
        NumberAnimation { target: hero; property: "press"; to: 0.97; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: hero; property: "press"; to: 1; duration: 140; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: openAnim
        // Flight and spin share one duration and easing, so the turn is always in proportion
        // to the distance covered: the card finishes its full turn exactly as it arrives.
        NumberAnimation { target: hero; property: "x"; to: inspect.heroX; duration: inspect.openDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: hero; property: "y"; to: inspect.heroY; duration: inspect.openDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: hero; property: "scale"; to: 1; duration: inspect.openDuration; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: hero; property: "spin"; from: 0; to: 360; duration: inspect.openDuration; easing.type: Easing.OutCubic }
            ScriptAction { script: hero.spin = 0 }
        }
        NumberAnimation { target: inspect; property: "level"; to: 1; duration: 220 * inspect.motion; easing.type: Easing.OutQuad }
        SequentialAnimation {
            PauseAnimation { duration: 90 * inspect.motion }
            NumberAnimation { target: inspect; property: "panelLevel"; to: 1; duration: 240 * inspect.motion; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: closeAnim
        property real toX
        property real toY
        property real toScale
        property real toOpacity: 1
        property real toSpin: 0
        ParallelAnimation {
            // The settling "place" sound lands with the card (its thump is ~125 ms in).
            SequentialAnimation {
                PauseAnimation { duration: Math.max(0, 300 * inspect.motion - 125) }
                ScriptAction { script: if (closeAnim.toOpacity > 0) inspect.appRoot.sound("place") }
            }
            // A flipped card turns face-up before it lands back in its recess.
            NumberAnimation { target: hero; property: "spin"; to: closeAnim.toSpin; duration: 300 * inspect.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: hero; property: "x"; to: closeAnim.toX; duration: 300 * inspect.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: hero; property: "y"; to: closeAnim.toY; duration: 300 * inspect.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: hero; property: "scale"; to: closeAnim.toScale; duration: 300 * inspect.motion; easing.type: Easing.InOutCubic }
            NumberAnimation { target: hero; property: "opacity"; to: closeAnim.toOpacity; duration: 300 * inspect.motion }
            NumberAnimation { target: inspect; property: "level"; to: 0; duration: 240 * inspect.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: inspect; property: "panelLevel"; to: 0; duration: 120 * inspect.motion; easing.type: Easing.InQuad }
        }
        ScriptAction { script: inspect.finishClose() }
    }

    ParallelAnimation {
        id: dismissAnim
        NumberAnimation { target: inspect; property: "level"; to: 0; duration: 260 * inspect.motion; easing.type: Easing.InQuad }
        NumberAnimation { target: inspect; property: "panelLevel"; to: 0; duration: 140 * inspect.motion; easing.type: Easing.InQuad }
    }

    // ------------------------------------------------------------ details

    // The details beside the card. The top (name, developer, Play) stays pinned; the rest
    // scrolls under it. Scrolling on down through the screenshots turns the view into
    // "gallery mode" (GalleryMorph), step by step with the scroll: the card slides off to the
    // left, still peeking, the first screenshot grows into the freed space and Play moves
    // up into the gallery's bar. Scrolling back up, or choosing the peeking card, returns.
    readonly property real peekW: 64
    readonly property real panelBaseX: inspect.wide ? inspect.heroX + inspect.heroW + inspect.gap : Math.round((inspect.width - inspect.panelW) / 2)
    readonly property real panelGalleryX: peekW + inspect.gap
    readonly property bool galleryMode: morph.galleryMode
    readonly property real galleryLevel: morph.level
    // Back to the details, the same way it came.
    function exitGallery() {
        morph.exit()
        playButton.forceActiveFocus()
    }

    GalleryView {
        id: galleryView
        x: inspect.panelGalleryX + (1 - inspect.galleryLevel) * 40
        y: Ui.gapXL
        width: inspect.width - inspect.panelGalleryX - 72
        height: inspect.height - 2 * Ui.gapXL
        opacity: inspect.panelLevel * morph.galleryOpacity
        visible: opacity > 0.01 || morph.morphing
        enabled: inspect.galleryMode
        morphing: morph.morphing
        info: inspect.info
        appRoot: inspect.appRoot
        title: inspect.game.title || ""
        subtitle: [inspect.game.developer || "",
                   inspect.game.released ? new Date(inspect.game.released * 1000).getFullYear().toString() : ""]
                  .filter(x => x).join("  ·  ")
        actionText: playButton.text
        actionIcon: playButton.icon.name
        actionEnabled: playButton.enabled
        onAction: {
            inspect.resetGallery()
            inspect.play()
        }
        onBack: inspect.exitGallery()
    }

    Item {
        id: detailsPanel
        readonly property real avail: inspect.wide ? inspect.height - 2 * Ui.gapXL
                                                   : inspect.height - (inspect.heroY + inspect.heroH + 28) - 20
        x: inspect.panelBaseX - inspect.galleryLevel * 40
        y: inspect.wide ? Math.max(Ui.gapXL, Math.min(Math.round(inspect.heroY + (inspect.heroH - height) / 2),
                                                      inspect.height - height - Ui.gapXL))
                        : inspect.heroY + inspect.heroH + 28
        width: detailsFlick.width
        height: pinned.height + Ui.gapXL + detailsFlick.height
        opacity: inspect.panelLevel * morph.detailsOpacity
        enabled: !inspect.galleryMode
        visible: opacity > 0.01 || morph.morphing
        // Slides in from the side the card comes from (the right when opening).
        transform: Translate { x: (1 - inspect.panelLevel) * 28 * inspect.panelDir }
        Accessible.role: Accessible.Dialog
        Accessible.name: inspect.game.title || ""

        // Pinned: always in view while the rest scrolls.
        Column {
            id: pinned
            width: inspect.panelW
            spacing: Ui.gapXL
            // Text sits on the scrim, so it uses light colors in both editions.
            Column {
                width: parent.width
                spacing: Ui.gapS
                Text {
                    text: (inspect.game.sourceName || "").toUpperCase()
                    color: Ui.onScrimDim
                    font.family: "Nunito"
                    font.weight: Font.Black
                    font.pixelSize: Ui.textBody
                    font.letterSpacing: 2.5
                }
                Text {
                    width: parent.width
                    text: inspect.game.title || ""
                    color: Ui.onScrim
                    font.family: "Nunito"
                    font.weight: Font.Black
                    font.pixelSize: Ui.textDisplay
                    lineHeight: 0.95
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                // Who made it: developer · publisher (if different) · year.
                // Steam games: each company links to its other games on Steam.
                Text {
                    readonly property var g: inspect.game
                    readonly property string year: g.released ? new Date(g.released * 1000).getFullYear().toString() : ""
                    visible: text !== ""
                    width: parent.width
                    topPadding: 2
                    textFormat: g.source === "steam" ? Text.StyledText : Text.PlainText
                    text: g.source === "steam" ? Ui.creditsLine(g.developer, g.publisher, year)
                        : [g.developer || "", g.publisher && g.publisher !== g.developer ? g.publisher : "", year]
                          .filter(x => x).join("  ·  ")
                    linkColor: Ui.onScrimDim
                    onLinkActivated: (url) => Backend.openUrl(url)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    color: Ui.onScrimDim
                    font.family: "Nunito"
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textLead
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            CButton {
                id: playButton
                width: parent.width
                big: true
                kind: "primary"
                opacity: morph.morphing ? 0 : 1
                readonly property real progress: !inspect.game.installed && Backend.installs
                                                 && Backend.installs.progress[inspect.game.gameId] !== undefined
                                                 ? Backend.installs.progress[inspect.game.gameId] : -1
                enabled: progress < 0
                text: inspect.game.installed ? "Play"
                    : progress >= 0 ? "Installing… " + Math.round(progress * 100) + "%" : "Install"
                icon.name: inspect.game.installed ? "media-playback-start-symbolic" : "download-symbolic"
                onClicked: inspect.play()
                Keys.onReturnPressed: inspect.play()
                Keys.onEnterPressed: inspect.play()
            }

            Flow {
                width: parent.width
                spacing: Ui.gapM
                readonly property bool steamGame: inspect.game.source === "steam"
                CButton {
                    visible: parent.steamGame
                    kind: "scrim"
                    text: "Open Store Page"
                    icon.name: "internet-services-symbolic"
                    onClicked: Backend.openUrl("steam://store/" + inspect.game.extId)
                }
                CButton {
                    visible: parent.steamGame
                    kind: "scrim"
                    text: "Show in Library"
                    icon.name: "view-list-icons-symbolic"
                    onClicked: Backend.openUrl("steam://nav/games/details/" + inspect.game.extId)
                }
                CButton {
                    id: otherButton
                    kind: "scrim"
                    text: "Other"
                    icon.name: "overflow-menu-symbolic"
                    onClicked: otherMenu.popup(otherButton, 0, otherButton.height + 6)
                }
            }

        }

        Flickable {
            id: detailsFlick
            y: pinned.height + Ui.gapXL
            // The column keeps its width; the scrollbar gets a lane of its own beside it.
            width: inspect.panelW + (contentHeight > height ? Ui.gapL : 0)
            height: Math.max(0, Math.min(details.height, detailsPanel.avail - pinned.height - Ui.gapXL))
            contentHeight: Math.max(details.height, morph.neededContentHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelAccel { id: detailsWheel; flickable: detailsFlick; step: 90 }
            onVisibleChanged: if (visible) contentY = 0
            QQC2.ScrollBar.vertical: CScrollBar { onDark: true }

            Column {
                id: details
                width: inspect.panelW
                spacing: Ui.gapXL
                Column {
                    spacing: Ui.gapS
                    Repeater {
                        model: [
                            { icon: "view-calendar-symbolic", text: inspect.lastPlayedText(inspect.game.lastPlayed) },
                            { icon: "chronometer-symbolic", text: inspect.playtimeText(inspect.game.playtime) },
                            { icon: inspect.game.installed ? "checkmark-symbolic" : "download-symbolic",
                              text: inspect.game.installed ? "Installed" : "Not installed" },
                            { icon: "system-run-symbolic", text: inspect.game.noSlot ? "Launches without a slot" : "" },
                        ]
                        delegate: Row {
                            required property var modelData
                            visible: modelData.text !== ""
                            spacing: Ui.gapM
                            CIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                source: modelData.icon
                                isMask: true
                                color: Ui.onScrimDim
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                color: Ui.onScrim
                                font.family: "Nunito"
                                font.weight: Font.DemiBold
                                font.pixelSize: Ui.textLead
                            }
                        }
                    }
                }

                // From the Steam store (loadFacts). Each part hides when empty.
                ReviewBadges {
                    width: parent.width
                    info: inspect.info
                    extraChips: inspect.extras.players ? [{ text: inspect.extras.players + " playing now", live: true }] : []
                }
                FoldSection {
                    width: parent.width
                    title: "About This Game"
                    text: inspect.info.about || inspect.info.description || ""
                }
                GameLinks {
                    width: parent.width
                    appid: inspect.game.source === "steam" ? (parseInt(inspect.game.extId) || 0) : 0
                    title: inspect.game.title || ""
                    website: inspect.info.website || ""
                    metacriticUrl: inspect.info.metacriticUrl || ""
                }
                MediaGallery {
                    id: mediaGallery
                    width: inspect.panelW
                    info: inspect.info
                    appRoot: inspect.appRoot
                    hideFirst: morph.morphing
                }
            }
        }
    }

    GalleryMorph {
        id: morph
        anchors.fill: parent
        flick: detailsFlick
        wheel: detailsWheel
        gallery: mediaGallery
        view: galleryView
        button: playButton
        active: inspect.open && inspect.wide
        motion: inspect.motion
        onEntered: galleryView.forceActiveFocus()
    }

    // Previous / next game, for the mouse (← → on the keyboard), and close.
    PageControls {
        anchors.fill: parent
        z: 1
        shown: inspect.open
        arrows: inspect.wide
        dice: true
        opacity: inspect.level  // (not the panel's: they stay put while stepping and rolling)
        onStep: (dir) => inspect.step(dir)
        onClose: inspect.close()
        onRoll: inspect.appRoot.rollDice()
    }

    CMenu {
        id: otherMenu
        readonly property bool custom: (inspect.game.gameId || "").startsWith("manual_")
        QQC2.Action {
            text: "Change Art…"
            icon.name: "insert-image-symbolic"
            enabled: !Backend.fake
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.changeArt(g.gameId, g.title)
            }
        }
        QQC2.Action {
            text: "Reposition Art…"
            icon.name: "transform-move-symbolic"
            enabled: !Backend.fake
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.repositionArt(g.gameId, g.title)
            }
        }
        QQC2.Action {
            text: "Change Header…"
            icon.name: "view-media-title-symbolic"
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.changeHeader(g.gameId, g.title, g.source)
            }
        }
        QQC2.Action {
            text: "Rename…"
            icon.name: "edit-rename-symbolic"
            enabled: !Backend.fake
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.renameGame(g.gameId, g.title)
            }
        }
        QQC2.Action {
            text: "Edit Play Time…"
            icon.name: "chronometer-symbolic"
            objectName: "optional" // Steam keeps its own count
            enabled: Backend.playtimeEditable(inspect.game.gameId || "")
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.editPlaytime(g.gameId, g.title)
            }
        }
        CMenuSeparator {}
        QQC2.Action {
            text: "Launch Without Slot"
            icon.name: "system-run-symbolic"
            checkable: true
            checked: inspect.game.noSlot === true
            onTriggered: {
                Backend.setNoSlot(inspect.game.gameId, !inspect.game.noSlot)
                const g = Object.assign({}, inspect.game)
                g.noSlot = !g.noSlot
                inspect.game = g
            }
        }
        QQC2.Action {
            text: "Game Process…"
            icon.name: "link-symbolic"
            enabled: !Backend.fake
            onTriggered: {
                const g = inspect.game
                inspect.close()
                inspect.appRoot.linkProcess(g.gameId, g.title)
            }
        }
        QQC2.Action {
            objectName: "optional"
            text: "Uninstall…"
            icon.name: "edit-delete-symbolic"
            enabled: inspect.game.installed === true && inspect.game.source === "steam"
            onTriggered: Backend.openUrl("steam://uninstall/" + inspect.game.extId)
        }
        QQC2.Action {
            text: otherMenu.custom ? "Remove Game…" : "Hide Game"
            objectName: otherMenu.custom ? "danger" : ""
            icon.name: otherMenu.custom ? "edit-delete-symbolic" : "view-hidden-symbolic"
            onTriggered: {
                const g = inspect.game
                inspect.close()
                if (otherMenu.custom) inspect.appRoot.confirmRemove(g.gameId, g.title)
                else inspect.appRoot.hideGame(g.gameId, g.title)
            }
        }
    }
}
