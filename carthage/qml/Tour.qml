// The first-use tour, after setup: the screen dims except for a spotlight on one control at a
// time, with a note and Next; "Skip tutorial" ends it at any point. Steps may open things (a
// game's view, the sidebar, the store) and it tidies up after itself.
//   tour.begin()
import QtQuick
import QtQuick.Shapes
import Carthage

Item {
    id: tour

    property Item appRoot
    property int step: -1
    property bool addedTest: false  // it turned the test cartridge on (an empty library) and turns it off after
    property rect hole: Qt.rect(0, 0, 0, 0)
    property bool hasHole: false
    readonly property bool running: step >= 0

    // Each step: what it says, what it lights up (an objectName), what it does first, and how
    // long that takes to settle before the light finds its target.
    readonly property var steps: [
        { text: "You can add any game or app through here.", target: "tourAdd", wait: 300,
          enter: () => tour.appRoot.navigate("library:all") },
        { text: "Feeling indecisive? Let Carthage pick a game for you.", target: "tourDice", wait: 100 },
        { text: "This bookmark adds a game to 'Play Next'. You can bookmark both games you own or don't own yet.", target: "tourBookmark", wait: 1000,
          enter: () => tour.openAGame() },
        { text: "You can access Play Next, or create more lists here.", target: "tourPlayNext", wait: 700,
          enter: () => { tour.appRoot.closeInspect(); tour.later(380, () => tour.appRoot.sidebarOpen = true) } },
        { text: "Carthage's Store shows you games from the Epic Games and the Steam Store.", target: "tourStore", wait: 700,
          enter: () => { tour.appRoot.sidebarOpen = false; tour.appRoot.navigate("store:discover") } },
        { text: "Search works across both your library and the store.", target: "tourSearch", wait: 700,
          enter: () => tour.showSearch() },
        { text: "You can tweak Carthage's settings from here.", target: "tourSettings", wait: 700,
          enter: () => { tour.clearSearch(); tour.appRoot.navigate("library:all"); tour.later(260, () => tour.appRoot.sidebarOpen = true) } },
        { text: "That's a wrap! I'll stop yapping now.", target: "", wait: 400,
          enter: () => tour.appRoot.sidebarOpen = false }
    ]

    function begin() {
        step = 0
        enterStep()
    }
    function next() {
        if (step >= steps.length - 1) return end()
        step++
        enterStep()
    }
    // Back: the previous step, with what it opens (the game's view, the sidebar, the store) put
    // right: everything is closed first and the step opens what it needs.
    function back() {
        if (step <= 0) return
        step--
        appRoot.closeInspect()
        appRoot.sidebarOpen = false
        clearSearch()
        const p = step === 4 ? "store:discover" : "library:all"
        if (step !== 5 && appRoot.page !== p) appRoot.navigate(p)
        const s = steps[step]
        if (step === 3) later(380, () => appRoot.sidebarOpen = true)  // (its own enter closes the game's view first)
        else if (step === 2 || step === 5 || step === 6) s.enter()
        startAiming(s)
    }
    // Search, with an example: one of your games' names typed in.
    function showSearch() {
        appRoot.navigate("search")
        const g = Backend.games.count ? Backend.gameInfo(Backend.games.idAt(0)) : {}
        const example = (g.title || "Portal").split(/[:\-–]/)[0].trim()
        Qt.callLater(() => { appRoot.parts.header.searchField.text = example })
    }
    function clearSearch() {
        appRoot.parts.header.searchField.text = ""
    }
    // Closing fades the whole tour out, then tidies up.
    property bool leaving: false
    function end() {
        if (leaving || !running) return
        leaving = true
        settle.stop()
        poll.stop()
        fadeOut.restart()
    }
    NumberAnimation {
        id: fadeOut
        target: tour
        property: "opacity"
        to: 0
        duration: 320 * Backend.motion
        easing.type: Easing.InOutQuad
        onFinished: tour.finish()
    }
    function finish() {
        leaving = false
        opacity = 1
        clearSearch()
        step = -1
        shown = false
        hasHole = false
        appRoot.closeInspect()
        appRoot.sidebarOpen = false
        if (addedTest) { Backend.settings.testCartridge = false; addedTest = false }
        if (appRoot.page !== "library:all") appRoot.navigate("library:all")
    }
    // The note and the spotlight appear together, only once the target has stopped moving (a
    // sidebar still sliding in, a view still opening), already in place: they fade in there and
    // never travel. Between steps they're gone at once.
    property bool shown: false
    property int shownStep: -1       // the step whose words the note shows (changes only while hidden)
    property rect lastSeen: Qt.rect(-1, -1, 0, 0)
    property int tries: 0
    function enterStep() {
        const s = steps[step]
        if (s.enter) s.enter()
        startAiming(s)
    }
    function startAiming(s) {
        shown = false
        hasHole = false
        tries = 0
        lastSeen = Qt.rect(-1, -1, 0, 0)
        settle.interval = (s.wait || 200) * Math.max(0.3, Backend.motion)
        settle.restart()
    }
    // The first game's view (with no games: the test cartridge's).
    function openAGame() {
        if (Backend.games.count === 0 && !Backend.settings.testCartridge) {
            Backend.settings.testCartridge = true
            addedTest = true
            later(600, openAGame)
            return
        }
        const cell = appRoot.cellFor(Backend.games.idAt(0))
        if (cell) appRoot.choose(cell)
    }
    property var laterFn: null
    function later(ms, fn) { laterFn = fn; laterTimer.interval = ms; laterTimer.restart() }
    Timer { id: laterTimer; onTriggered: if (tour.laterFn) tour.laterFn() }

    function find(item, name) {
        if (!item) return null
        if (item.objectName === name && item.visible) return item
        for (const c of item.children) {
            const f = find(c, name)
            if (f) return f
        }
        return null
    }
    function aim() {
        if (!running) return
        const name = steps[step].target
        const t = name ? find(appRoot, name) : null
        if (!name || (!t && tries > 40)) {  // nothing to light (the last step), or it never came: the note in the middle
            hasHole = false
            reveal()
            return
        }
        if (!t) { tries++; poll.restart(); return }
        const p = t.mapToItem(tour, 0, 0)
        const m = 8
        const r = Qt.rect(Math.round(p.x - m), Math.round(p.y - m), Math.round(t.width + 2 * m), Math.round(t.height + 2 * m))
        const still = r.x === lastSeen.x && r.y === lastSeen.y && r.width === lastSeen.width && r.height === lastSeen.height
        lastSeen = r
        if (!still && tries++ < 60) { poll.restart(); return }  // still moving: look again
        hole = r
        hasHole = true
        reveal()
    }
    function reveal() {
        shownStep = step
        shown = true
        follow.restart()
    }
    Timer { id: settle; onTriggered: tour.aim() }
    Timer { id: poll; interval: 50; onTriggered: tour.aim() }
    // Once shown: if the target later moves (the window resized), the spotlight and note follow.
    Timer {
        id: follow
        running: tour.shown && tour.hasHole
        interval: 250
        repeat: true
        onTriggered: {
            const t = tour.find(tour.appRoot, tour.steps[tour.step].target)
            if (!t) return
            const p = t.mapToItem(tour, 0, 0)
            tour.hole = Qt.rect(Math.round(p.x - 8), Math.round(p.y - 8), Math.round(t.width + 16), Math.round(t.height + 16))
        }
    }

    visible: running
    anchors.fill: parent
    z: 985
    // Only the tour takes input meanwhile: keys too (no arrows, Esc or typing reaching the app).
    focus: running
    onRunningChanged: if (running) forceActiveFocus()
    Keys.onPressed: (e) => e.accepted = true

    // Everything behind waits for the tour.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => w.accepted = true
    }

    // The dim, around the spotlight (or all over when nothing is lit): one shape with the
    // spotlight cut out of it, its corners rounded like the rim.
    readonly property color dim: Qt.rgba(0, 0, 0, 0.55)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: tour.dim
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathRectangle { x: 0; y: 0; width: tour.width; height: tour.height }
            PathRectangle {
                x: tour.hole.x; y: tour.hole.y
                width: tour.hasHole ? tour.hole.width : 0
                height: tour.hasHole ? tour.hole.height : 0
                radius: tour.hasHole ? 12 : 0
            }
        }
    }
    Rectangle {  // the spotlight's rim
        visible: tour.hasHole
        opacity: note.opacity
        x: tour.hole.x
        y: tour.hole.y
        width: tour.hole.width
        height: tour.hole.height
        radius: 12
        color: "transparent"
        border.width: 2
        border.color: Backend.theme.accent.accent
    }

    // The note: below the spotlight if there's room, else above; centred with nothing lit.
    Item {
        id: note
        width: Math.min(360, parent.width - 32)
        height: noteBody.implicitHeight + 32
        readonly property bool below: tour.hole.y + tour.hole.height + height + 24 < tour.height
        x: tour.hasHole ? Math.max(16, Math.min(tour.width - width - 16, tour.hole.x + tour.hole.width / 2 - width / 2))
                        : (tour.width - width) / 2
        y: !tour.hasHole ? (tour.height - height) / 2
           : below ? tour.hole.y + tour.hole.height + 14 : tour.hole.y - height - 14
        opacity: 0
        visible: opacity > 0.01
        Connections {
            target: tour
            function onShownChanged() {
                noteFade.stop()
                if (tour.shown) noteFade.start()
                else note.opacity = 0
            }
        }
        NumberAnimation { id: noteFade; target: note; property: "opacity"; from: 0; to: 1; duration: 200 * Backend.motion; easing.type: Easing.OutQuad }
        PanelBackground { anchors.fill: parent; radius: 16 }
        Column {
            id: noteBody
            x: 16
            y: 16
            width: parent.width - 32
            spacing: Ui.gapM
            Text {
                width: parent.width
                text: tour.shownStep >= 0 ? tour.steps[tour.shownStep].text : ""
                color: Backend.theme.p.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                wrapMode: Text.Wrap
            }
            Item {
                width: parent.width
                height: nextButton.height
                Row {
                    spacing: Ui.gapS
                    CButton {
                        visible: tour.shownStep < tour.steps.length - 1
                        text: "Skip tutorial"
                        onClicked: tour.end()
                    }
                    CButton {
                        visible: tour.shownStep > 0
                        text: "Back"
                        onClicked: if (tour.shown) { tour.appRoot.sound("key"); tour.back() }
                    }
                }
                Text {
                    anchors.right: nextButton.left
                    anchors.rightMargin: Ui.gapM
                    anchors.verticalCenter: parent.verticalCenter
                    text: (tour.shownStep + 1) + " / " + tour.steps.length
                    color: Backend.theme.p.panelTextDim
                    font.family: Ui.fontText
                    font.pixelSize: Ui.textCaption
                }
                CButton {
                    id: nextButton
                    anchors.right: parent.right
                    kind: "primary"
                    text: tour.shownStep >= tour.steps.length - 1 ? "Done" : "Next"
                    onClicked: if (tour.shown) { tour.appRoot.sound("key"); tour.next() }
                }
            }
        }
    }
}
