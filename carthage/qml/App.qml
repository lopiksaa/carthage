// Everything in the window: tray, dock, closer look and cartridge flights. Reloaded live in dev
// mode.
import QtQuick
import Carthage

Item {
    id: app

    readonly property var pal: Backend.theme.p
    // The desktop's animation-speed factor (KDE setting on Linux; 1 elsewhere); 0 = instant.
    readonly property real motion: Backend.motion
    readonly property bool animate: motion > 0
    property string mode: "library"
    // Discord Rich Presence follows the open screen (Python ignores it unless switched on).
    function updatePresence() { Backend.setPresence(mode, Backend.sessions.count > 0) }
    onModeChanged: updatePresence()
    Connections {
        target: Backend.sessions
        function onCountChanged() { app.updatePresence() }
    }
    Timer { running: true; interval: 800; onTriggered: app.updatePresence() }
    function setMode(m) {
        if (m === mode) return
        if (inspect.open) inspect.close()
        mode = m
        header.searchField.text = ""
        if (m === "store") storeView.load()
        else focusTray()
    }
    function search(text) {
        if (mode === "store") storeView.query = text
        else Backend.games.filterText = text
    }
    function showOwned(gid) {
        setMode("library")
        Backend.games.filterText = ""
        Qt.callLater(function () {
            const row = Backend.games.rowOf(gid)
            if (row < 0) return
            tray.positionViewAtIndex(row, GridView.Contain)
            Qt.callLater(function () {
                const c = tray.cellFor(gid)
                if (c) choose(c)
            })
        })
    }
    // True while any window/panel sits on top of the tray and dock: they then ignore input,
    // because Qt's tap handlers can still see clicks underneath a modal popup.
    readonly property bool modalOpen: artPicker.opened || cropEditor.opened || confirm.opened
                                      || headerPicker.opened || textPrompt.opened || processPicker.opened
                                      || storePage.open || mediaViewer.opened
                                      || addGameDialog.opened || slotPanel.opened || inspect.open
                                      || colorPicker.opened || whatsNew.opened || feedbackDialog.opened
                                      || app.settingsOpen || Ui.openMenus > 0

    // gameId → true while the cartridge is out of its recess (inspected, flying or docked).
    property var hiddenCards: ({})
    // gameId → true while a slot is waiting for its flying cartridge.
    property var pendingSeat: ({})

    function setHidden(gameId, value) {
        const h = Object.assign({}, hiddenCards)
        if (value) h[gameId] = true
        else delete h[gameId]
        hiddenCards = h
    }
    function focusTray() {
        tray.forceActiveFocus()
    }
    function notify(message, actionText, callback) {
        if (actionText) Window.window.showPassiveNotification(message, "long", actionText, callback)
        else Window.window.showPassiveNotification(message, "short")
    }
    function announce(message) {
        dock.Accessible.announce(message)
    }
    function sound(name) {
        sounds.play(name)
    }
    function windowMinimized() {
        const w = Window.window
        return !w || w.visibility === Window.Minimized || w.visibility === Window.Hidden
    }
    function cellFor(gid) {
        return tray.cellFor(gid)
    }
    function isCellVisible(cell) {
        return tray.isCellVisible(cell)
    }
    function cardData(from) {
        return {
            gameId: from.gameId, title: from.title, source: from.source,
            sourceName: from.sourceName, sourceIcon: from.sourceIcon, code: from.code,
            extId: from.extId, installed: from.installed, noSlot: from.noSlot,
        }
    }
    function copyCard(data, to) {
        for (const k in data)
            if (k in to) to[k] = data[k]
    }

    // Primary action on a card: take a closer look (the confirmation step), never an
    // instant launch — so a stray click can't start a game.
    function choose(cell) {
        if (Backend.sessions.indexOf(cell.gameId) >= 0) {
            cell.nudge()
            const s = dock.slotFor(cell.gameId)
            if (s) {
                s.nudge()
                openSlotPanel(s)
            }
            return
        }
        inspect.openFor(cell)
    }

    function quickPlay(cell) {
        const s0 = 1 + 0.05 * cell.lift
        const base = cell.mapToItem(flightLayer, cell.cardX, cell.cardY - cell.cardW * 0.035 * cell.lift)
        play(cardData(cell), {
            x: base.x + cell.cardW * (1 - s0) / 2,
            y: base.y + cell.cardH * (1 - s0) / 2,
            scale: s0, cardWidth: cell.cardW, lift: 0.6 + 0.4 * cell.lift,
        }, function () { cell.press() })
    }

    // Launch `data` and fly its cartridge from `start` (flight-layer geometry) into a slot.
    // `notFlying` runs when the launch doesn't use a slot (install, launch without slot).
    // Returns the launch result.
    function play(data, start, notFlying) {
        const gid = data.gameId
        pendingSeat[gid] = true
        const result = Backend.launch(gid)
        if (result !== "slot") delete pendingSeat[gid]

        if (result === "install") {
            if (notFlying) notFlying()
            notify("Opening Steam to install " + data.title + ". It'll light up here when it's done.")
            return result
        }
        if (result === "install-elsewhere") {
            if (notFlying) notFlying()
            notify(data.title + " isn't installed. Install it in " + data.sourceName.charAt(0)
                   + data.sourceName.slice(1).toLowerCase() + ".")
            return result
        }
        if (result === "noslot") {
            if (notFlying) notFlying()
            notify("Starting " + data.title + "…")
            return result
        }
        if (result !== "slot") return result

        setHidden(gid, true)
        announce("Starting " + data.title)

        const slot = dock.slotFor(gid)
        if (!animate || !slot) {
            delete pendingSeat[gid]
            if (slot) slot.seatIn()
            return result
        }
        const f = flyerComponent.createObject(flightLayer, {
            x: start.x, y: start.y, scale: start.scale, cardWidth: start.cardWidth,
            motion: app.motion, lift: start.lift,
        })
        copyCard(data, f.cart)
        const seat = dock.seatPos(Backend.sessions.indexOf(gid))
        const target = dock.mapToItem(flightLayer, seat.x, seat.y - dock.riseHeight)
        f.launch(target.x, target.y, dock.cartW / start.cardWidth, function () {
            delete app.pendingSeat[gid]
            const s = dock.slotFor(gid)
            if (s) s.seatIn()
            f.destroy()
        })
        return result
    }

    property bool dragging: false
    property string dragTarget: ""   // "favorites" | "tray" | "dock" | ""
    property var dragData: null
    property Item dragCell: null
    property CardDrag dragProxy: null
    property point dragHome      // where it was picked up from (flight-layer coordinates)
    function startCardDrag(cell, scenePos, grab) {
        if (dragging || modalOpen) return
        dragCell = cell
        dragData = cardData(cell)
        dragData.favorite = Backend.isFavorite(cell.gameId)
        const f = cardDragComponent.createObject(flightLayer, {
            cardW: cell.cardW, grabX: grab.x, grabY: grab.y, motion: app.motion,
        })
        copyCard(dragData, f.cart)
        const p = flightLayer.mapFromItem(null, scenePos.x, scenePos.y)
        f.x = p.x - grab.x * cell.cardW
        f.y = p.y - grab.y * cell.cardH
        dragHome = cell.mapToItem(flightLayer, cell.cardX, cell.cardY)
        dragProxy = f
        dragging = true
        setHidden(cell.gameId, true)  // its recess shows empty while it's out
        sound("pick")
        moveCardDrag(scenePos)
    }
    function dropTargetAt(scenePos) {
        const d = dock.mapFromItem(null, scenePos.x, scenePos.y)
        if (d.y > -dock.protrude * 0.6 && d.x >= 0 && d.x <= dock.width) return "dock"
        if (mode !== "library") return ""
        const zone = tray.headerItem ? tray.headerItem.dropZone : null
        if (zone && zone.visible) {
            const z = zone.mapFromItem(null, scenePos.x, scenePos.y)
            if (z.x >= 0 && z.y >= -12 && z.x <= zone.width && z.y <= zone.height + 12)
                return dragData.favorite ? "" : "favorites"
        }
        const t = tray.mapFromItem(null, scenePos.x, scenePos.y)
        if (dragData.favorite && t.x >= 0 && t.y >= 0 && t.x <= tray.width && t.y <= tray.height) return "tray"
        return ""
    }
    function moveCardDrag(scenePos) {
        if (!dragging) return
        const p = flightLayer.mapFromItem(null, scenePos.x, scenePos.y)
        dragProxy.follow(p.x, p.y)
        const t = dropTargetAt(scenePos)
        if (t !== dragTarget && t) sound("hover")
        dragTarget = t
        dragProxy.overDock = t === "dock"
        dragProxy.hint = t === "favorites" ? "Add to Favorites"
                       : t === "tray" ? "Back to the Tray"
                       : t === "dock" ? (dragData.installed ? "Play" : "Install") : ""
        dragProxy.hintIcon = t === "favorites" ? "starred-symbolic"
                           : t === "dock" ? (dragData.installed ? "media-playback-start-symbolic" : "download-symbolic")
                           : t === "tray" ? "view-grid-symbolic" : ""
    }
    // The drag stopped without a drop (the pointer was taken away): spring back home.
    function cancelCardDrag() {
        endCardDrag(null)
    }
    function endCardDrag(scenePos) {
        if (!dragging) return
        const target = scenePos ? dropTargetAt(scenePos) : ""
        const f = dragProxy, data = dragData, gid = data.gameId
        dragging = false
        dragTarget = ""
        dragProxy = null
        if (target === "dock") {
            const start = { x: f.x, y: f.y, scale: f.scale, cardWidth: f.cardW, lift: 1 }
            const result = play(data, start, null)
            if (result === "slot") {
                f.destroy()
                return
            }
            settleCard(f, gid, true)  // installing / launched without a slot: back to its recess
            return
        }
        if (target === "favorites" || target === "tray") {
            Backend.setFavorite(gid, target === "favorites")
            sound("place")
            Qt.callLater(() => settleCard(f, gid, false))
            return
        }
        sound("release")
        settleCard(f, gid, true)
    }
    function settleCard(f, gid, home) {
        // The tray and shelf make a new recess on their next layout; do it now, so the
        // cartridge can fly into it instead of appearing there.
        tray.forceLayout()
        if (tray.shelfItem && tray.shelfItem.forceLayout) tray.shelfItem.forceLayout()
        const cell = tray.cellFor(gid)
        f.settled.connect(() => {
            setHidden(gid, false)
            const c = tray.cellFor(gid)
            if (c) c.press()  // it lands with a little bump
            f.destroy()
        })
        if (home) {
            const c = dragCell && dragCell.gameId === gid ? dragCell : null
            const p = c ? c.mapToItem(flightLayer, c.cardX, c.cardY) : dragHome
            f.springTo(p.x, p.y)
        } else if (cell && tray.isCellVisible(cell)) {
            const p = cell.mapToItem(flightLayer, cell.cardX, cell.cardY)
            f.springTo(p.x, p.y)
        } else {
            f.settle(f.x, f.y + 30, 0.9)  // its new recess is out of view: set it down there
        }
    }
    Component {
        id: cardDragComponent
        CardDrag {}
    }

    function openSlotPanel(s) {
        slotPanel.openFor(s)
    }
    function slotPanelFor(s) {
        return slotPanel.opened && slotPanel.slot === s
    }
    function closeSlotPanel() {
        slotPanel.close()
    }
    function openDockMenu(gid) {
        const s = dock.slotFor(gid)
        if (s && s.seated) openSlotPanel(s)
    }

    function confirmQuit(gid, title, force) {
        confirm.ask(force ? "Force quit " + title + "?" : "Quit " + title + "?",
                    force ? "The game will be stopped immediately. Unsaved progress will be lost."
                          : "Unsaved progress may be lost.",
                    force ? "Force Quit" : "Quit Game",
                    function () {
                        if (force) Backend.sessions.forceQuit(gid)
                        else Backend.sessions.quit(gid)
                        sounds.play("half_click")
                    })
    }

    function revealInTray(gid) {
        const row = Backend.games.rowOf(gid)
        if (row >= 0) {
            tray.positionViewAtIndex(row, GridView.Contain)
            tray.currentIndex = row
        }
    }
    function showInTray(gid) {
        const row = Backend.games.rowOf(gid)
        if (row < 0) {
            notify(Backend.titleOf(gid) + " is hidden or filtered out of the tray.")
            return
        }
        tray.positionViewAtIndex(row, GridView.Contain)
        tray.currentIndex = row
        const c = tray.cellFor(gid)
        if (c) c.nudge()
    }

    // Dice: a random game that isn't in the dock.
    property string diceSpot: ""  // the card the light is on
    function rollDice() {
        if (diceTimer.running || diceScroll.running) return
        const current = inspect.open ? inspect.game.gameId : ""
        const pool = []
        for (const m of [Backend.favorites, Backend.games])
            for (let r = 0; r < m.count; r++) {
                const id = m.idAt(r)
                if (id !== current && Backend.sessions.indexOf(id) < 0) pool.push(id)
            }
        if (!pool.length) {
            notify(current ? "There's no other game to pick." : "There's no game to pick.")
            return
        }
        const pick = pool[Math.floor(Math.random() * pool.length)]
        sound("roll")
        if (inspect.open) inspect.rollTo(pick, pool)
        else if (motion <= 0) {
            bringIntoView(pick, false)
            landDice(pick)
        } else {
            diceTimer.pick = pick
            bringIntoView(pick, true)
        }
    }
    function bringIntoView(gid, glide) {
        const fav = Backend.favorites.rowOf(gid)
        const row = Backend.games.rowOf(gid)
        const shelf = tray.shelfItem
        if (fav >= 0 && shelf && shelf.positionViewAtIndex) shelf.positionViewAtIndex(fav, GridView.Contain)
        const cell = tray.cellFor(gid)
        let to = tray.contentY
        if (!cell || !tray.isCellVisible(cell)) {
            const from = tray.contentY
            if (fav >= 0) tray.positionViewAtBeginning()
            else tray.positionViewAtIndex(row, GridView.Center)
            to = tray.contentY
            if (glide) tray.contentY = from
        }
        if (!glide) return
        if (to === tray.contentY) {
            startHops()
            return
        }
        diceScroll.to = to
        diceScroll.restart()
    }
    NumberAnimation {
        id: diceScroll
        target: tray
        property: "contentY"
        duration: 420 * app.motion
        easing.type: Easing.InOutCubic
        onFinished: app.startHops()
    }
    function startHops() {
        const cells = []
        for (const grid of [tray, tray.shelfItem]) {
            if (!grid || !grid.contentItem) continue
            for (const c of grid.contentItem.children)
                if (c.gameId && c.gameId !== diceTimer.pick && !c.out && tray.isCellVisible(c)) cells.push(c.gameId)
        }
        const hops = []
        for (let i = 0; i < 7 && cells.length; i++) {
            let id = cells[Math.floor(Math.random() * cells.length)]
            if (cells.length > 1 && id === hops[i - 1]) id = cells[(cells.indexOf(id) + 1) % cells.length]
            hops.push(id)
        }
        diceTimer.hops = hops.concat([diceTimer.pick])
        diceTimer.k = 0
        diceTimer.interval = 1
        diceTimer.start()
    }
    Timer {
        id: diceTimer
        property string pick
        property var hops: []
        property int k: 0
        onTriggered: {
            // Something else took over (a click, a drag, the drawer): the light goes out.
            if (inspect.open || app.settingsOpen || app.mode !== "library" || app.dragging) {
                app.diceSpot = ""
                return
            }
            if (k < hops.length) {
                app.diceSpot = hops[k]
                app.sound("hover")
                k++
                interval = k === hops.length ? 420 : 55 + 5 * k * k
                start()
                return
            }
            app.landDice(pick)
            app.diceSpot = ""
        }
    }
    function landDice(gid) {
        let cell = tray.cellFor(gid)
        if (!cell) {  // scrolled away meanwhile
            bringIntoView(gid, false)
            cell = tray.cellFor(gid)
        }
        if (cell) choose(cell)
    }

    function confirmClearCache(onYes) {
        confirm.ask("Clear the cache?", "Downloaded art and store data are deleted and fetched again. Art you picked yourself is kept.",
                    "Clear Cache", onYes)
    }

    function confirmResetSettings() {
        confirm.ask("Reset all settings?",
                    "The look, sound, library order and store settings go back to the defaults, and so do "
                    + "your favorites, hidden games, names and cartridge headers. Your API keys, play time "
                    + "and the art you picked stay.",
                    "Reset", function () {
                        Backend.resetSettings()
                        notify("Settings are back to the defaults.")
                    })
    }

    function confirmRemove(gid, title) {
        confirm.ask("Remove " + title + "?", "It's removed from Carthage only. Nothing is uninstalled.",
                    "Remove", function () { Backend.removeCustomGame(gid) })
    }

    function hideGame(gid, title) {
        Backend.setHidden(gid, true)
        notify(title + " hidden", "Undo", function () { Backend.setHidden(gid, false) })
    }

    function ejected(gid, reason) {
        const title = Backend.titleOf(gid)
        if (reason === "crashed") notify(title + " closed right after starting.")
        announce(title + " closed")

        const slot = dock.slotFor(gid)
        if (slotPanel.opened && slotPanel.slot === slot) slotPanel.close()
        const release = function () { Backend.sessions.release(gid) }
        if (!slot || !animate || windowMinimized()) {
            setHidden(gid, false)
            if (slot) slot.seated = false
            release()
            return
        }
        sounds.play("release")
        slot.riseOut(function () {
            const p = slot.cartTopLeft(flightLayer)
            const f = flyerComponent.createObject(flightLayer, {
                x: p.x, y: p.y, cardWidth: tray.cardW, scale: dock.cartW / tray.cardW,
                motion: app.motion, lift: 0.35,
            })
            copyCard({
                gameId: slot.gameId, title: slot.title, source: slot.source,
                sourceName: slot.sourceName, sourceIcon: slot.sourceIcon, code: slot.code, extId: slot.extId,
            }, f.cart)
            slot.seated = false
            release()

            const land = function () {
                app.setHidden(gid, false)
                f.destroy()
            }
            const cell = tray.cellFor(gid)
            if (app.mode !== "library") {
                const b = header.libraryButtonCenter(flightLayer)
                const s = f.scale * 0.25
                f.flyAway(b.x - tray.cardW * s / 2, b.y - tray.cardW * Backend.theme.ratio * s / 2, land, 0.25)
            } else if (cell && tray.isCellVisible(cell)) {
                const t = cell.mapToItem(flightLayer, cell.cardX, cell.cardY)
                f.flyBack(t.x, t.y, land)
            } else {
                const row = Backend.games.rowOf(gid)
                const above = row >= 0 && cell === null ? row < tray.indexAt(tray.contentX + 10, tray.contentY + 10)
                                                       : (cell ? cell.mapToItem(flightLayer, 0, 0).y < 0 : false)
                const tx = flightLayer.width / 2 - tray.cardW / 2
                const ty = above ? -tray.cardW * 1.6 : flightLayer.height * 0.3
                f.flyAway(tx, ty, land)
            }
        })
    }

    Connections {
        target: Backend.updater
        property bool told: false
        function onChanged() {
            if (told || !Backend.updater.available) return
            if (Backend.updater.automatic && Backend.updater.state !== "failed") {
                if (Backend.updater.state !== "ready") return
                told = true
                app.notify("Carthage " + Backend.updater.latest + " is ready. It installs when Carthage restarts.",
                           "Restart Now", function () { Backend.updater.restartNow() })
            } else {
                told = true
                app.notify("Carthage " + Backend.updater.latest + " is out.", "Download",
                           function () { Backend.updater.download() })
            }
        }
    }

    Connections {
        target: Backend
        function onLibraryError(details) {
            app.notify("Couldn't read part of your game library. Showing what could be read.")
            console.warn(details)
        }
    }

    Connections {
        target: Backend.sessions
        function onEnding(gameId, reason) {
            app.ejected(gameId, reason)
        }
        function onStateChanged(gameId, state) {
            const t = Backend.titleOf(gameId)
            if (state === "running") app.announce("Playing " + t)
            else if (state === "notresponding") app.announce(t + " isn't responding")
        }
    }

    Component.onCompleted: {
        Window.window.searchField = header.searchField
        const problems = Backend.libraryProblems()
        if (problems) notify("Couldn't read " + problems + ". Details are in " + Backend.logFile(), "long")
        // Cartridges already in the dock (startup or live reload) are out of their recesses.
        const h = {}
        for (let i = 0; i < Backend.sessions.count; i++) {
            const gid = Backend.sessions.data(Backend.sessions.index(i, 0), Qt.UserRole + 1)
            if (gid) h[gid] = true
        }
        hiddenCards = h
    }

    property real drawerProgress: 0
    property bool settingsOpen: false  // where it's heading
    function toggleDrawer() {
        if (settingsOpen) closeDrawer()
        else openDrawer()
    }
    function openDrawer() {
        if (inspect.open) inspect.close()
        settingsOpen = true
        drawerAnim.to = 1
        drawerAnim.easing.type = Easing.OutCubic
        drawerAnim.duration = 280 * motion
        drawerAnim.restart()
        drawer.focusFirst()
    }
    function closeDrawer() {
        if (!settingsOpen) return
        settingsOpen = false
        drawerAnim.to = 0
        drawerAnim.easing.type = Easing.InOutCubic
        drawerAnim.duration = 220 * motion
        drawerAnim.restart()
        focusTray()
    }
    NumberAnimation {
        id: drawerAnim
        target: app
        property: "drawerProgress"
    }

    SideDrawer {
        id: drawer
        appRoot: app
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        visible: app.drawerProgress > 0
        onCloseRequested: app.closeDrawer()
    }

    Item {
        id: slide
        width: app.width
        height: app.height
        x: -drawer.width * app.drawerProgress

        Item {
            id: stage
            anchors.fill: parent

            Item {
                id: body
                // One rule for the whole app: while anything sits on top (closer look, store
                // page, dialog, menu, drawer), nothing behind it takes clicks, hover or scroll.
                enabled: !app.modalOpen
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Rectangle {
                    anchors.fill: parent
                    color: app.pal.tray
                }
                Image {
                    anchors.fill: parent
                    source: "image://gc/grain/" + Backend.theme.edition + Backend.theme.texQuery
                    fillMode: Image.Tile
                    opacity: 0.2
                    smooth: false
                }

                LibraryBar {
                    id: libraryBar
                    visible: app.mode === "library"
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    tray: tray
                    appRoot: app
                }
                Tray {
                    id: tray
                    appRoot: app
                    visible: app.mode === "library"
                    anchors.top: libraryBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: dock.top
                    bottomClearance: dock.protrude - dock.lipY + Ui.spacingLarge
                }
                StoreView {
                    id: storeView
                    appRoot: app
                    visible: app.mode === "store"
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: dock.top
                    bottomClearance: dock.protrude - dock.lipY + Ui.spacingLarge
                    onChosen: (it, cart, siblings) => storePage.openFor(it, siblings)
                }

                Rectangle {
                    id: dockFade
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: Ui.gridUnit // keep the scrollbar visible
                    anchors.bottom: dock.top
                    height: dock.protrude - dock.lipY + Ui.gridUnit * 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(app.pal.tray, 0) }
                        GradientStop { position: 0.55; color: Qt.alpha(app.pal.tray, 0.92) }
                        GradientStop { position: 1.0; color: app.pal.tray }
                    }
                }

                // Guard band: the strip right above the dock, where docked cartridges stick up, never
                // reaches the cards behind it — so aiming for a docked cartridge can't start another
                // game. Scrolling still passes through.
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: Ui.gridUnit
                    anchors.bottom: dock.top
                    height: dock.protrude - dock.lipY + 10
                    hoverEnabled: true
                    acceptedButtons: Qt.AllButtons
                    onWheel: (wheel) => wheel.accepted = false
                }

                CPlaceholder {
                    anchors.centerIn: tray
                    width: tray.width - Ui.gridUnit * 4
                    readonly property string filter: Backend.games.filterMode
                    visible: Backend.games.count + Backend.favorites.count === 0 && app.mode === "library"
                    iconName: Backend.games.filterText ? "search" : "applications-games"
                    text: Backend.games.filterText ? "No games match “" + Backend.games.filterText + "”"
                        : filter === "installed" ? "No installed games"
                        : filter === "notinstalled" ? "Everything is installed"
                        : "No games yet"
                    explanation: Backend.games.filterText ? "Try a different name, or clear the search."
                        : filter !== "all" ? "Set Show to All in the bar above to see the rest."
                        : "Carthage finds games from Steam, Heroic, Lutris and more. Add any other game with + above."
                }

                Dock {
                    id: dock
                    appRoot: app
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    onClicked: {
                        sounds.play("click_in")
                        dock.bump()
                    }
                }
            }

            Header {
                id: header
                appRoot: app
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                z: 2
            }
        }

        StorePage {
            id: storePage
            anchors.fill: parent
            appRoot: app
            stage: stage
            z: 50
        }

        Inspect {
            id: inspect
            anchors.fill: parent
            appRoot: app
            stage: stage
            z: 50
        }

        Item {
            id: flightLayer
            anchors.fill: parent
            z: 100
        }

        Rectangle {
            visible: app.drawerProgress > 0
            x: parent.width
            width: 40
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5 * app.drawerProgress) }
                GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.18 * app.drawerProgress) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: app.drawerProgress > 0
            z: 200
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.4 * app.drawerProgress) }
                GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.52 * app.drawerProgress) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7 * app.drawerProgress) }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                onClicked: app.closeDrawer()
                onWheel: (wheel) => wheel.accepted = true
            }
        }
    }

    SlotPanel {
        id: slotPanel
        appRoot: app
    }

    ConfirmDialog {
        id: confirm
    }

    ArtPicker {
        id: artPicker
        appRoot: app
    }
    function changeArt(gid, title) {
        artPicker.openFor(gid, title)
    }
    CropEditor {
        id: cropEditor
    }
    HeaderPicker {
        id: headerPicker
        appRoot: app
    }
    Connections {
        target: Backend
        function onHeaderImageFailed(message) { app.notify(message) }
    }
    ProcessPicker {
        id: processPicker
    }
    MediaViewer {
        id: mediaViewer
    }
    function viewMedia(list, i) {
        mediaViewer.openAt(list, i)
    }
    function linkProcess(gid, title) {
        processPicker.openFor(gid, title)
    }
    TextPrompt {
        id: textPrompt
    }
    function changeHeader(gid, title, source) {
        headerPicker.openFor(gid, title, source)
    }
    function customHeaderText(gid, title) {
        textPrompt.ask("Custom Header", "Printed across the top of the cartridge.",
                       Backend.headerTextOf(gid) || title, "Save",
                       function (v) { Backend.setHeaderText(gid, v) })
    }
    function editPlaytime(gid, title) {
        textPrompt.ask("Edit Play Time", "Total time played in " + title + ", in hours — for example 12 or 3.5.",
                       Backend.playtimeHours(gid), "Save",
                       function (v) {
                           if (!Backend.setPlaytime(gid, v))
                               notify("That isn't a number of hours. Try again with something like 12 or 3.5.")
                       })
    }
    function renameGame(gid, title) {
        textPrompt.ask("Rename Game", "Only changes the name in Carthage.", title, "Rename",
                       function (v) { Backend.rename(gid, v) },
                       "Original Name", function () { Backend.rename(gid, "") })
    }
    function repositionArt(gid, title) {
        cropEditor.openFor(gid, title)
    }

    AddGameDialog {
        id: addGameDialog
        appRoot: app
    }
    function addGame() {
        closeDrawer()
        addGameDialog.start()
    }

    ColorPickerDialog {
        id: colorPicker
    }
    function pickColor(target) {  // "hardware" or "card"
        colorPicker.openFor(target)
    }
    SetupWizard {
        id: setupWizard
        appRoot: app
    }
    function runSetup() {
        closeDrawer()
        setupWizard.start()
    }
    WhatsNewDialog { id: whatsNew; appRoot: app }
    function showWhatsNew() {
        closeDrawer()
        whatsNew.openWith(Backend.whatsNewNotes(), false)
    }
    Timer {
        running: !!Backend.whatsNew.version && app.powered
        interval: 900
        onTriggered: if (!setupWizard.opened && !app.modalOpen) whatsNew.openWith(Backend.whatsNew, true)
    }
    Timer {
        running: Backend.firstRun
        interval: 700
        onTriggered: setupWizard.start()
    }

    Sounds { id: sounds }

    // Feedback: after 40 minutes of use (counted while the window is active, across runs),
    // a toast asks once. Menu → System → Send Feedback is always there.
    FeedbackPrompt {
        id: feedbackPrompt
        appRoot: app
        z: 50
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.height + 16
    }
    Timer {
        interval: 60000
        repeat: true
        running: app.powered && !Backend.settings.feedbackAsked && Qt.application.state === Qt.ApplicationActive
        onTriggered: {
            Backend.settings.usageMinutes += 1
            if (Backend.settings.usageMinutes >= 40 && !app.modalOpen && !app.dragging && !setupWizard.opened) {
                Backend.settings.feedbackAsked = true
                feedbackPrompt.show()
            }
        }
    }
    FeedbackDialog { id: feedbackDialog; appRoot: app }
    function sendFeedback() {
        closeDrawer()
        feedbackDialog.start()
    }

    NumberAnimation {
        id: autoScroll
        target: tray
        property: "contentY"
        easing.type: Easing.InOutQuad
    }

    Component {
        id: flyerComponent
        Flyer {}
    }

    Shortcut {
        sequence: "F10"
        onActivated: app.toggleDrawer()
    }
    Shortcut {
        sequence: "Esc"
        enabled: app.settingsOpen
        onActivated: app.closeDrawer()
    }
    Shortcut {
        sequence: "F6"
        enabled: !inspect.open
        onActivated: tray.activeFocus ? dock.focusFirst() : tray.forceActiveFocus()
    }

    readonly property bool powered: powerOn.powered
    PowerOn {
        id: powerOn
        anchors.fill: parent
        z: 1000
    }

    function demo(cmd) {
        switch (cmd.do) {
        case "hover": {
            const c = tray.cellAt(cmd.index)
            if (c) c.debugHover = cmd.x === undefined ? null : Qt.point(cmd.x, cmd.y)
            break
        }
        case "choose": {
            const c = tray.cellAt(cmd.index)
            if (c) {
                c.debugHover = null
                choose(c)
            }
            break
        }
        case "play": // skip the closer look
        {
            const c = tray.cellAt(cmd.index)
            if (c) quickPlay(c)
            break
        }
        case "inspectPlay":
            inspect.play()
            break
        case "dump": { // print every session's title and state
            const out = []
            for (let i = 0; i < Backend.sessions.count; i++) {
                const idx = Backend.sessions.index(i, 0)
                out.push(Backend.sessions.data(idx, Qt.UserRole + 2) + "=" + Backend.sessions.data(idx, Qt.UserRole + 3))
            }
            console.warn("SESSIONS", out.length ? out.join(", ") : "(none)")
            break
        }
        case "quitAll":
            for (let i = 0; i < Backend.sessions.count; i++)
                Backend.sessions.quit(Backend.sessions.data(Backend.sessions.index(i, 0), Qt.UserRole + 1))
            break
        case "drawerScroll":
            drawer.scrollToEnd()
            break
        case "artPicker": {
            const c = tray.cellAt(cmd.index)
            if (c) changeArt(c.gameId, c.title)
            break
        }
        case "crop": {
            const c = tray.cellAt(cmd.index)
            if (c) repositionArt(c.gameId, c.title)
            break
        }
        case "pickerKind":
            artPicker.kind = cmd.value
            artPicker.load()
            break
        case "otherMenu":
            inspect.openOther()
            break
        case "state":
            console.warn("STATE inspect.open=" + inspect.open + " picker=" + artPicker.opened
                         + " crop=" + cropEditor.opened + " sessions=" + Backend.sessions.count
                         + " drawer=" + app.settingsOpen + " storePage=" + storePage.open + " menus=" + Ui.openMenus
                         + " trayY=" + Math.round(tray.contentY) + " drawerY=" + Math.round(drawer.scrollY))
            break
        case "headerPicker": {
            const c = tray.cellAt(cmd.index)
            if (c) changeHeader(c.gameId, c.title, c.source)
            break
        }
        case "setHeader": {
            const c = tray.cellAt(cmd.index)
            if (c) Backend.setHeader(c.gameId, cmd.value)
            break
        }
        case "pickerSearch":
            artPicker.searchText(cmd.value)
            break
        case "fakeInstall": {
            const c = tray.cellAt(cmd.index)
            if (c) Backend.installs.simulate(c.gameId, cmd.value)
            break
        }
        case "finishInstall": {
            const c = tray.cellAt(cmd.index)
            if (c) Backend.demoFinishInstall(c.gameId)
            break
        }
        case "search":
            header.searchField.text = cmd.value
            break
        case "storeBrowse":
            storeView.showCategories()
            break
        case "storeCategory":
            storeView.openCategory(Backend.store.categories[cmd.index])
            break
        case "mode":
            setMode(cmd.value)
            break
        case "storeViewer":
            viewMedia(storePage.media, cmd.index || 0)
            break
        case "storeScroll":
            storePage.scrollDetails(cmd.y)
            break
        case "storeOpen": {
            const s = storeView.sections[cmd.section || 0]
            if (s) storePage.openFor(s.items[cmd.index || 0], s.items)
            break
        }
        case "storeOpenResult":  // {"index": n} opens a search result
            if (storeView.results[cmd.index || 0]) storePage.openFor(storeView.results[cmd.index || 0], storeView.results)
            break
        case "storeOpenFree":  // {"index": n} opens a game from Free for a Limited Time
            if (storeView.free[cmd.index || 0]) storePage.openFor(storeView.free[cmd.index || 0], storeView.free)
            break
        case "storeShuffle":  // {"dir": 1} turns the store page's cartridge to the next store
            storePage.shuffle(cmd.dir || 1)
            break
        case "confirmDemo":
            confirmQuit("x", "Clair Obscur: Expedition 33", false)
            break
        case "renameDemo": {
            const c = tray.cellAt(cmd.index || 0)
            if (c) renameGame(c.gameId, c.title)
            break
        }
        case "processDemo": {
            const c = tray.cellAt(cmd.index || 0)
            if (c) linkProcess(c.gameId, c.title)
            break
        }
        case "closeAll":  // every dialog, menu, page and the drawer (each on its own, so one can't stop the rest)
            for (const p of [artPicker, cropEditor, confirm, headerPicker, textPrompt, processPicker, addGameDialog, setupWizard, slotPanel, mediaViewer, colorPicker, whatsNew, feedbackDialog])
                try { p.close() } catch (e) { console.warn("closeAll:", e) }
            for (const f of [() => inspect.closeMenus(), () => tray.closeMenus(), () => storePage.close(), () => inspect.close(), () => closeDrawer()])
                try { f() } catch (e) { console.warn("closeAll:", e) }
            break
        case "addDialog":
            addGameDialog.start()
            break
        case "settingsSection":  // {"id": "look"} opens settings on that section
            openDrawer()
            drawer.openSection = cmd.id
            break
        case "feedbackDialog":  // Send Feedback; optional {"text", "answer": true, "email"}
            sendFeedback()
            if (cmd.text) feedbackDialog.text = cmd.text
            if (cmd.answer) feedbackDialog.wantsAnswer = true
            if (cmd.email) feedbackDialog.emailText = cmd.email
            break
        case "feedbackSend":  // presses Send (test runs never send anything)
            feedbackDialog.send()
            break
        case "feedbackPrompt":  // the one-time feedback toast; {"dismiss": true} closes it
            if (cmd.dismiss) feedbackPrompt.dismiss()
            else feedbackPrompt.show()
            break
        case "whatsNew":  // the What's new window for this version ({"step": n} to jump)
            showWhatsNew()
            if (cmd.step) whatsNew.step = cmd.step
            break
        case "setup": // {"step": n} opens the setup wizard on that step
            setupWizard.start()
            setupWizard.step = cmd.step || 0
            break
        case "dice":
            rollDice()
            break
        case "galleryBack":  // leave gallery mode (closer look or store page)
            if (storePage.open) storePage.exitGallery()
            else inspect.exitGallery()
            break
        case "colorPicker":  // {"target": "hardware" | "card"}
            pickColor(cmd.target || "hardware")
            break
        case "setting":  // {"key": "testCartridge", "value": false} — test runs never save settings
            Backend.settings[cmd.key] = cmd.value
            break
        case "banner":  // {"name": "CONTROL"} turns the store banner to that game
            console.warn("BANNER", storeView.showInBanner(cmd.name))
            break
        case "inspectScroll":
            inspect.scrollDetails(cmd.y)
            break
        case "step":  // ← / → on the open closer look or store page
            if (storePage.open) storePage.step(cmd.dir)
            else inspect.step(cmd.dir)
            break
        case "inspectFlip":
            inspect.flip()
            break
        case "drawer":
            toggleDrawer()
            break
        case "inspectClose":
            inspect.close()
            break
        case "quit": {
            const gid = Backend.sessions.data(Backend.sessions.index(cmd.slot, 0), Qt.UserRole + 1)
            Backend.sessions.quit(gid)
            sounds.play("half_click")
            break
        }
        case "edition":
            Backend.settings.hardware = ({ 0: "black", 1: "white", 2: "black" })[cmd.value] || cmd.value
            break
        case "focus":
            tray.forceActiveFocus()
            tray.currentIndex = cmd.index
            break
        case "cardWidth":
            Backend.settings.cardWidth = cmd.value
            break
        case "set": // {"target": "games" | "settings", "prop": ..., "value": ...}
            Backend[cmd.target][cmd.prop] = cmd.value
            break
        case "key": // keyboard navigation: {"key": "right" | "down" | ...}
            tray.forceActiveFocus()
            tray.keyboardNav = true
            if (cmd.key === "right") tray.moveCurrentIndexRight()
            else if (cmd.key === "down") tray.moveCurrentIndexDown()
            break
        case "scroll":
            if (mode === "store") storeView.scrollTo(cmd.y)
            else tray.contentY = cmd.y
            break
        case "autoscroll": // performance check: scroll the whole tray over `ms`
            autoScroll.duration = cmd.ms
            autoScroll.to = Math.max(0, tray.contentHeight - tray.height)
            autoScroll.restart()
            break
        case "slotpanel": {
            const s = dock.slotFor(Backend.sessions.data(Backend.sessions.index(cmd.slot, 0), Qt.UserRole + 1))
            if (s) openSlotPanel(s)
            break
        }
        case "slotmenu": {
            const s = dock.slotFor(Backend.sessions.data(Backend.sessions.index(cmd.slot, 0), Qt.UserRole + 1))
            if (s) s.openContextMenu(false)
            break
        }
        case "menu": {
            const c = tray.cellAt(cmd.index)
            if (c) c.openMenu(false)
            break
        }
        }
    }
}
