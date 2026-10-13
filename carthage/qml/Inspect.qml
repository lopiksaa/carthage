// The closer look at a library game (GameView): the card lifted out of the tray next to its
// details. It's also the confirmation step, so a stray click never launches a game.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

GameView {
    id: inspect

    property var game: ({})
    property var extras: ({})
    readonly property var pal: Backend.theme.p
    readonly property int appid: game.source === "steam" ? (parseInt(game.extId) || 0) : 0

    warmUp: true
    showDice: true
    detailsObjectName: "inspectDetails"  // for the test harness
    cardGame: game
    eyebrow: game.sourceName || ""
    title: game.title || ""
    credits: {
        const g = game
        const year = g.released ? new Date(g.released * 1000).getFullYear().toString() : ""
        return g.source === "steam" ? Ui.creditsLine(g.developer, g.publisher, year)
             : [g.developer || "", g.publisher && g.publisher !== g.developer ? g.publisher : "", year]
               .filter(x => x).join("  ·  ")
    }
    gallerySubtitle: [game.developer || "", game.released ? new Date(game.released * 1000).getFullYear().toString() : ""]
                     .filter(x => x).join("  ·  ")
    mainButton: playButton
    backdropUrl: info.background || ""
    detailsPending: appid > 0 && Object.keys(info).length === 0

    onCloseRequested: close()
    onStepRequested: (dir) => step(dir)
    onRollRequested: appRoot.rollDice()

    function loadFacts() {
        info = {}
        extras = {}
        detailsLoading()
        if (Backend.fake || !game.gameId || game.source === "carthage") return
        if (appid) Backend.store.loadDetailsQuiet(appid)
        Backend.store.loadExtras(game.gameId, appid, game.title || "")
        preloadNeighbours()
    }
    // The games ← and → go to (running games are skipped).
    function neighbourId(dir) {
        for (let r = Backend.games.rowOf(game.gameId) + dir; r >= 0 && r < Backend.games.count; r += dir) {
            const id = Backend.games.idAt(r)
            if (Backend.sessions.indexOf(id) < 0) return id
        }
        return ""
    }
    // The previous and next games' backdrops load ahead: their details, then their pictures
    // (into the image cache, at the size the backdrop asks for).
    property var neighbourAppids: []
    property var preloadUrls: []
    function preloadNeighbours() {
        const ids = []
        for (const d of [-1, 1]) {
            const gid = neighbourId(d)
            const g = gid ? Backend.gameInfo(gid) : {}
            const a = g.source === "steam" ? parseInt(g.extId) || 0 : 0
            if (a) ids.push(a)
        }
        neighbourAppids = ids
        for (const a of ids) Backend.store.loadDetailsQuiet(a)
    }
    Repeater {
        model: Backend.settings.gameBackground === "blur" ? [] : inspect.preloadUrls
        Image {
            required property string modelData
            visible: false
            source: modelData
            asynchronous: true
            cache: true
            sourceSize.width: 1600  // (GameBackdrop's)
        }
    }
    Connections {
        target: Backend.store
        function onDetailsReady(appid, data) {
            if (appid === inspect.appid && appid > 0) inspect.info = data
            else if (inspect.neighbourAppids.indexOf(appid) >= 0 && data.background)
                inspect.preloadUrls = inspect.preloadUrls.filter(u => u !== data.background).concat([data.background]).slice(-4)
        }
        function onExtrasReady(key, data) {
            if (key === inspect.game.gameId) inspect.extras = data
        }
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

    // `game` is a snapshot: pick up an install that finishes while the view is open.
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
        // later changes to its fields.
        const g = appRoot.cardData(cell)
        const pc = cell.mapToItem(null, cell.cardX + cell.cardW / 2, cell.cardY + cell.cardH / 2)
        Ui.groundPulse(pc.x, pc.y)  // the ground answers the opening
        g.lastPlayed = cell.lastPlayed
        g.playtime = cell.playtime
        g.developer = cell.developer
        g.publisher = cell.publisher
        g.released = cell.released
        g.family = Backend.gameInfo(g.gameId).family === true
        game = g
        backdrop.clear()  // (not the last game's art fading out as this one opens)
        loadFacts()
        const s0 = 1 + 0.05 * cell.lift
        const base = cell.mapToItem(inspect, cell.cardX, cell.cardY - cell.cardW * 0.035 * cell.lift)
        appRoot.setHidden(game.gameId, true)
        appRoot.sound("pick")
        flyIn(base.x + cell.cardW * (1 - s0) / 2, base.y + cell.cardH * (1 - s0) / 2, s0 * cell.cardW / heroW)
    }

    // The tray scrolls along, so closing still flies the card back into the right pocket.
    function step(dir) {
        if (!open || animating || rolling) return
        const gid = neighbourId(dir)
        if (!gid) return nudge()
        otherMenu.close()
        const next = Backend.gameInfo(gid)
        stepTo(dir, () => swapTo(next))
    }
    function swapTo(data) {
        appRoot.setHidden(game.gameId, false)
        game = data
        appRoot.setHidden(game.gameId, true)
        appRoot.revealInTray(game.gameId)
        loadFacts()
        afterSwap()
    }

    // The dice: the card turns through a few games and lands on the one picked.
    property bool rolling: false
    property var rollFaces: []
    // Rolling while scrolled down (looking at screenshots): back to the top first, then roll.
    Timer {
        id: rollAfterReset
        property string gid
        property var pool
        interval: 240 * Math.max(inspect.motion, 0.01)
        onTriggered: inspect.rollTo(gid, pool)
    }
    function rollTo(gid, pool) {
        if (!open || animating || rolling) return
        if (detailsFlick.contentY > 1 && motion > 0) {
            detailsWheel.glideTo(0, 220 * motion)
            rollAfterReset.gid = gid
            rollAfterReset.pool = pool
            rollAfterReset.restart()
            return
        }
        otherMenu.close()
        stopTurning()
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
        NumberAnimation { target: inspect.hero; property: "spin"; from: 0; to: 90; duration: turnAnim.q * inspect.motion; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                const g = Backend.gameInfo(turnAnim.next)
                if (turnAnim.last) inspect.swapTo(g)
                else inspect.game = g
                inspect.appRoot.sound("hover")
            }
        }
        NumberAnimation {
            target: inspect.hero; property: "spin"; from: -90; to: 0
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

    function close() {
        if (!open) return
        if (rolling) {
            rolling = false
            rollOut.stop()
            turnAnim.stop()
        }
        otherMenu.close()
        const cell = appRoot.cellFor(game.gameId)
        const spot = cell && appRoot.isCellVisible(cell) ? cell.mapToItem(inspect, cell.cardX, cell.cardY) : null
        const done = () => {
            appRoot.setHidden(game.gameId, false)
            appRoot.focusTray()
        }
        if (spot) {
            flyOut(spot.x, spot.y, cell.cardW / heroW, 1, done)
        } else {
            // Its pocket isn't on screen: the card slides away toward it (up if it's above the
            // visible tray, otherwise down).
            const row = Backend.games.rowOf(game.gameId)
            const top = appRoot.firstVisibleRow()
            const up = row >= 0 && top >= 0 && row < top
            flyOut(hero.x, up ? -heroH * 1.4 : inspect.height + 40, hero.scale, 1, done)
        }
    }

    function play() {
        if (!open) return
        stopTurning()
        if (hero.showingBack || turning) {
            frontThenPlay.restart()
            return
        }
        const result = appRoot.play(game, {
            x: hero.x, y: hero.y, scale: hero.scale, cardWidth: heroW, lift: 1,
        }, function () { heroPress.restart() })
        if (result === "slot") {
            dismiss()
            appRoot.focusTray()
        } else if (result === "noslot" || result === "running") {
            close()
        }
    }
    SequentialAnimation {
        id: frontThenPlay
        NumberAnimation {
            target: inspect.hero
            property: "spin"
            to: Math.ceil(inspect.hero.spin / 360) * 360
            duration: 260 * inspect.motion
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                inspect.hero.spin = 0
                inspect.play()
            }
        }
    }
    SequentialAnimation {
        id: heroPress
        NumberAnimation { target: inspect.hero; property: "press"; to: 0.97; duration: 80 * inspect.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: inspect.hero; property: "press"; to: 1; duration: 140 * inspect.motion; easing.type: Easing.OutBack }
    }

    // Beside where it's from: a game lent by the Steam Family says so.
    eyebrowExtra: Row {
        visible: inspect.game.family === true
        spacing: 6
        Accessible.role: Accessible.StaticText
        Accessible.name: "Shared by your Steam Family"
        CIcon {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            source: "group-symbolic"
            color: Ui.onScrimDim
        }
        Text {
            text: "FAMILY"
            color: Ui.onScrimDim
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textBody
            font.letterSpacing: 2.5
        }
    }

    // Play, then Play Next and More as small keys beside it.
    actions: [
        CButton {
            id: playButton
            opacity: inspect.standIn ? 0 : 1
            width: parent.width - 2 * (height + Ui.gapM)
            big: true
            kind: "primary"
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
        },
        CButton {
            // Mentioning playNextStore re-checks it whenever Play Next changes.
            readonly property bool next: Backend.playNextStore, Backend.isPlayNext(inspect.game.gameId || "")
            objectName: "tourBookmark"  // (the first-run tour points at it)
            kind: "scrim"
            width: playButton.height
            height: playButton.height
            icon.name: next ? "bookmark-filled-symbolic" : "bookmark-symbolic"
            Accessible.name: next ? "Remove from Play Next" : "Add to Play Next"
            QQC2.ToolTip.visible: tipWanted
            QQC2.ToolTip.text: Accessible.name
            QQC2.ToolTip.delay: 300
            onClicked: Backend.setPlayNext(inspect.game.gameId, !next)
        },
        CButton {
            id: otherButton
            objectName: "inspectOtherButton"  // for the test harness
            kind: "scrim"
            width: playButton.height
            height: playButton.height
            icon.name: "overflow-menu-symbolic"
            Accessible.name: "More for this game"
            QQC2.ToolTip.visible: tipWanted
            QQC2.ToolTip.text: "More"
            QQC2.ToolTip.delay: 300
            onClicked: otherMenu.openFrom(otherButton)
        }
    ]

    details: [
        Flow {  // the facts, side by side
            width: parent.width
            spacing: Ui.gapXL
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
                        font.family: Ui.fontText
                        font.weight: Font.DemiBold
                        font.pixelSize: Ui.textLead
                    }
                }
            }
        },
        ReviewBadges {
            width: parent.width
            info: inspect.info
            extraChips: inspect.extras.players ? [{ text: inspect.extras.players + " playing now", live: true }] : []
        },
        AchievementsSection {
            objectName: "achievements"  // for the test harness
            width: parent.width
            appid: inspect.appid
        },
        FoldSection {
            width: parent.width
            title: "About This Game"
            text: inspect.info.about || inspect.info.description || ""
        },
        GameLinks {
            width: parent.width
            appid: inspect.appid
            title: inspect.game.title || ""
            website: inspect.info.website || ""
            metacriticUrl: inspect.info.metacriticUrl || ""
        }
    ]

    CMenu {
        id: otherMenu
        objectName: "inspectOtherMenu"  // for the test harness
        readonly property bool custom: (inspect.game.gameId || "").startsWith("manual_")
        readonly property bool steamGame: inspect.game.source === "steam"
        QQC2.Action {
            objectName: "optional"
            text: "Open Store Page"
            icon.name: "internet-services-symbolic"
            enabled: otherMenu.steamGame
            onTriggered: Backend.openUrl("steam://store/" + inspect.game.extId)
        }
        QQC2.Action {
            objectName: "optional"
            text: "Show in Steam Library"
            icon.name: "document-open-symbolic"
            enabled: otherMenu.steamGame
            onTriggered: Backend.openUrl("steam://nav/games/details/" + inspect.game.extId)
        }
        CMenuSeparator {
            visible: otherMenu.steamGame
            height: visible ? implicitHeight : 0
        }
        QQC2.Action {
            text: "Add to List…"
            icon.name: "view-list-icons-symbolic"
            onTriggered: inspect.appRoot.addToList(inspect.game.gameId, inspect.game.title)
        }
        CMenuSeparator {}
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
            text: "Cartridge Color…"
            icon.name: "color-picker-symbolic"
            onTriggered: inspect.appRoot.pickGameColor(inspect.game.gameId, inspect.game.title)
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
            icon.name: "tag-symbolic"
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
