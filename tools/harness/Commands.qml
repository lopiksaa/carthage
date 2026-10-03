// The test harness's commands (tools/harness/run.py sends them): each drives Carthage the way
// a person would, for scripted screenshots and checks. Not part of the app or the downloads.
// `app` is Carthage's App.qml (its `parts` name the pieces used here); `harness` is run.py's
// helper: find(objectName), mouseMove(x, y), install(gameId, fraction), finishInstall(gameId).
import QtQuick
import Carthage

QtObject {
    property Item app
    property QtObject harness

    // Turns the store banner to a game by name (from the spotlight, or any shelf).
    function showInBanner(name) {
        const view = app.parts.storeView
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
        if (i >= 0) Qt.callLater(() => harness.find("storeBanner").go(i))
        return i
    }

    function run(cmd) {
        const { addGameDialog, artPicker, autoScroll, colorPicker, confirm, cropEditor, dock, drawer, feedbackDialog, feedbackPrompt, header, headerPicker, inspect, mediaViewer, processPicker, setupWizard, slotPanel, sounds, storePage, storeView, textPrompt, tray, whatsNew } = app.parts
        const changeArt = (...a) => app.changeArt(...a)
        const changeHeader = (...a) => app.changeHeader(...a)
        const choose = (...a) => app.choose(...a)
        const closeDrawer = (...a) => app.closeDrawer(...a)
        const confirmQuit = (...a) => app.confirmQuit(...a)
        const linkProcess = (...a) => app.linkProcess(...a)
        const openDrawer = (...a) => app.openDrawer(...a)
        const openSlotPanel = (...a) => app.openSlotPanel(...a)
        const pickColor = (...a) => app.pickColor(...a)
        const play = (...a) => app.play(...a)
        const quickPlay = (...a) => app.quickPlay(...a)
        const renameGame = (...a) => app.renameGame(...a)
        const repositionArt = (...a) => app.repositionArt(...a)
        const rollDice = (...a) => app.rollDice(...a)
        const search = (...a) => app.search(...a)
        const sendFeedback = (...a) => app.sendFeedback(...a)
        const setMode = (...a) => app.setMode(...a)
        const showWhatsNew = (...a) => app.showWhatsNew(...a)
        const toggleDrawer = (...a) => app.toggleDrawer(...a)
        const viewMedia = (...a) => app.viewMedia(...a)
        switch (cmd.do) {
        case "hover": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) {  // a real pointer over the card ({x, y} as fractions of it), or away
                const p = c.mapToItem(null, c.cardX + (cmd.x === undefined ? -1 : cmd.x) * c.cardW,
                                      c.cardY + (cmd.y === undefined ? -1 : cmd.y) * c.cardH)
                harness.mouseMove(p.x, p.y)
            }
            break
        }
        case "choose": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) {
                choose(c)
            }
            break
        }
        case "play": // skip the closer look
        {
            const c = tray.itemAtIndex(cmd.index)
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
            const f = harness.find("drawerFlick")
            f.contentY = Math.max(0, f.contentHeight - f.height)
            break
        case "artPicker": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) changeArt(c.gameId, c.title)
            break
        }
        case "crop": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) repositionArt(c.gameId, c.title)
            break
        }
        case "pickerKind":
            artPicker.kind = cmd.value
            artPicker.load()
            break
        case "otherMenu":
            const b = harness.find("inspectOtherButton")
            harness.find("inspectOtherMenu").popup(b, 0, b.height + 6)
            break
        case "state":
            console.warn("STATE inspect.open=" + inspect.open + " picker=" + artPicker.opened
                         + " crop=" + cropEditor.opened + " sessions=" + Backend.sessions.count
                         + " drawer=" + app.settingsOpen + " storePage=" + storePage.open + " menus=" + Ui.openMenus
                         + " trayY=" + Math.round(tray.contentY) + " drawerY=" + Math.round(harness.find("drawerFlick").contentY))
            break
        case "headerPicker": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) changeHeader(c.gameId, c.title, c.source)
            break
        }
        case "setHeader": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) Backend.setHeader(c.gameId, cmd.value)
            break
        }
        case "pickerSearch":
            harness.find("artPickerSearch").text = cmd.value
            break
        case "fakeInstall": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) harness.install(c.gameId, cmd.value)
            break
        }
        case "finishInstall": {
            const c = tray.itemAtIndex(cmd.index)
            if (c) harness.finishInstall(c.gameId)
            break
        }
        case "search":
            header.searchField.text = cmd.value
            break
        case "storeFilter":  // {"store": "steam"|"epic"|"all", "genre": tag}
            if (cmd.store !== undefined) storeView.filterStore = cmd.store
            if (cmd.genre !== undefined) storeView.filterGenre = cmd.genre
            break
        case "sidebar":  // {"collapsed": bool}
            Backend.settings.sidebarCollapsed = cmd.collapsed
            break
        case "navigate":  // {"page": "store:deals"} (the sidebar layout concept)
            app.navigate(cmd.page)
            break
        case "searchPage":  // {"text": "…", "genres": [tag], "sale": bool}
            if (cmd.text !== undefined) app.parts.searchPage.text = cmd.text
            if (cmd.genres !== undefined) app.parts.searchPage.setGenres(cmd.genres)
            if (cmd.sale !== undefined) app.parts.searchPage.sale = cmd.sale
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
            harness.find("storePageDetails").contentY = cmd.y
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
            const c = tray.itemAtIndex(cmd.index || 0)
            if (c) renameGame(c.gameId, c.title)
            break
        }
        case "processDemo": {
            const c = tray.itemAtIndex(cmd.index || 0)
            if (c) linkProcess(c.gameId, c.title)
            break
        }
        case "closeAll":  // every dialog, menu, page and the drawer (each on its own, so one can't stop the rest)
            for (const p of [artPicker, cropEditor, confirm, headerPicker, textPrompt, processPicker, addGameDialog, setupWizard, slotPanel, mediaViewer, colorPicker, whatsNew, feedbackDialog])
                try { p.close() } catch (e) { console.warn("closeAll:", e) }
            for (const f of [() => harness.find("inspectOtherMenu").close(), () => harness.find("cardMenu").close(), () => storePage.close(), () => inspect.close(), () => closeDrawer()])
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
        case "playNext":  // {"ids": ["fake0", …], "store": [{appid, name, capsule, header}, …]} bookmarks them
            for (const id of cmd.ids || []) Backend.setPlayNext(id, true)
            for (const it of cmd.store || []) Backend.setPlayNextStore(it, true)
            break
        case "favorite":  // {"ids": ["fake0", …]} puts these games on the favorites shelf
            for (const id of cmd.ids || []) Backend.setFavorite(id, true)
            break
        case "setting":  // {"key": "testCartridge", "value": false} — test runs never save settings
            Backend.settings[cmd.key] = cmd.value
            break
        case "banner":  // {"name": "CONTROL"} turns the store banner to that game
            console.warn("BANNER", showInBanner(cmd.name))
            break
        case "inspectScroll":
            harness.find("inspectDetails").contentY = cmd.y
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
            if (app.mode === "store") {
                const v = harness.find("storeShelves")
                v.contentY = cmd.y - v.topMargin
            }
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
            const c = tray.itemAtIndex(cmd.index)
            if (c) c.openMenu(false)
            break
        }
        }
    
    }
}
