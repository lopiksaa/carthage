// The dock: a console base floating at the bottom of the library (design handoff, Spec §5).
// One shell with a saddle — an 11-px dip where the slots sit, one bay per docked game. Left
// wing: the status in words with a glyph backing them up. Right wing: keys acting on the
// selected cartridge (Switch to Game, Quit — or Eject when Carthage can't follow the game,
// Force Quit and Keep Waiting when it isn't responding), a groove, then the clock.
// Glass: a live blur of what's behind, tinted; Plastic: the hardware's plastic.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Shapes
import Carthage

Item {
    id: dock

    property Item appRoot
    property var behind: []           // for the glass: the layers under the dock, bottom first
    property bool floating: false     // (kept for App: the dock always floats now)
    property bool valley: false       // (kept for App)
    property real hideY: 0            // slid down out of sight by this much

    readonly property var pal: Backend.theme.p
    readonly property var g: Backend.theme.glass
    readonly property bool glassy: Backend.theme.glassy
    readonly property real motion: appRoot ? appRoot.motion : 1

    // Geometry (Spec §5).
    readonly property real shellH: 64
    readonly property real r: 22
    readonly property real saddle: 11          // d: the dip's depth
    readonly property real curve: 22           // t: each curve's width
    readonly property real pad: 20
    readonly property real wingGap: 16
    readonly property real pitch: 84
    readonly property real cartW: 64
    readonly property real cartH: cartW * Backend.theme.ratio
    readonly property real lipY: saddle + 3    // the slot line: cartridges are cut off here
    readonly property real protrude: 62        // the most a cartridge shows above it
    readonly property real riseHeight: 0       // (App: flights aim straight at seatPos)
    readonly property real rise: 0

    readonly property int filled: Backend.sessions.count
    readonly property int bays: Math.max(1, filled)
    height: shellH
    // The whole dock takes the pointer: hovering its middle mustn't hover (and click) the
    // cartridges behind it.
    HoverHandler { blocking: true }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = false
    }

    // The selected cartridge: the keys and the status follow it.
    property string selectedId: ""
    function select(gid) {
        selectedId = gid
    }
    readonly property Item sel: {
        const s = slotFor(selectedId)
        return s && s.state_ !== "ended" ? s : fallbackSel
    }
    property Item fallbackSel: null
    function refreshActive() {
        let attention = null, last = null
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i)
            if (!s || s.state_ === "ended") continue
            if (s.state_ === "notresponding") attention = s
            last = s
        }
        fallbackSel = attention || last
        if (attention && (!slotFor(selectedId) || slotFor(selectedId).state_ !== "notresponding"))
            selectedId = attention.gameId
    }
    Connections {
        target: Backend.sessions
        function onDataChanged() { dock.refreshActive() }
        function onCountChanged() { Qt.callLater(dock.refreshActive) }
    }

    function slotFor(gameId) {
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i)
            if (s && s.gameId === gameId) return s
        }
        return null
    }
    function bayX(i) { return x0 + i * pitch }      // a bay's left edge (each is 88 wide)
    // Where a flying cartridge lands: its top-left, the whole cartridge just above the slot
    // line (seating then slides it in), in dock coordinates.
    function seatPos(i) {
        return Qt.point(bayX(Math.max(0, i)) + Math.round((88 - cartW) / 2), lipY - cartH)
    }
    // The same, in the dock's parent, once the dock has finished growing or shrinking: a flight
    // aims there, so the cartridge doesn't drift with the shell after it lands.
    function landingPos(i) {
        const x0T = pad + leftWTarget + wingGap + curve
        const wT = x0T + flatTarget + curve + wingGap + rightWTarget + pad
        const left = parent ? (parent.width - wT) / 2 : x
        return Qt.point(left + x0T + Math.max(0, i) * pitch + Math.round((88 - cartW) / 2), y + lipY - cartH)
    }
    function focusFirst() {
        const s = slots.itemAt(0)
        if (s) s.forceActiveFocus()
    }
    function bump() { nudgeShell() }
    property real bumpY: 0
    function nudgeShell() {
        if (motion > 0) bumpAnim.restart()
    }
    SequentialAnimation {
        id: bumpAnim
        NumberAnimation { target: dock; property: "bumpY"; to: 1; duration: 50 * dock.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: dock; property: "bumpY"; to: 0; duration: 70 * dock.motion; easing.type: Easing.InQuad }
    }
    transform: Translate { y: dock.bumpY + dock.hideY }
    signal clicked()

    // ── What the dock says and offers ──
    readonly property var installing: {
        const p = Backend.installs ? Backend.installs.progress : ({})
        const ids = Object.keys(p)
        if (!ids.length) return null
        return { title: Backend.titleOf(ids[0]) || "a game", progress: p[ids[0]], more: ids.length - 1 }
    }
    readonly property bool gettingArt: !sel && !installing && !!Backend.artPicker && Backend.artPicker.pending > 0
    property int tick: 0
    Timer {
        interval: 30000
        repeat: true
        running: dock.filled > 0
        onTriggered: dock.tick++
    }
    function playTime(gid) {
        const t0 = Backend.sessions.startedAt(gid) + 0 * tick
        if (!t0) return ""
        const m = Math.floor((Date.now() / 1000 - t0) / 60)
        if (m < 1) return "just started"
        if (m < 60) return m + " min"
        return Math.floor(m / 60) + "h " + (m % 60) + "m"
    }
    // glyph: ready · busy (ring with a quarter arc) · playing · closing · warn
    readonly property var status: {
        const s = sel
        if (!s) {
            if (installing) return { glyph: "busy", a: "Installing ", b: installing.title,
                                     two: Math.round(installing.progress * 100) + "%" + (installing.more ? ", and " + installing.more + " more" : "") }
            if (gettingArt) return { glyph: "busy", a: "Getting art", b: "", two: Backend.artPicker.pending + " left" }
            return { glyph: "ready", a: "Ready", b: "", two: "" }
        }
        const more = filled > 1 ? " · " + filled + " games running" : ""
        switch (s.state_) {
        case "starting":
            return { glyph: "busy", a: s.statusText, b: "", two: s.title + more }
        case "running":
            return { glyph: "playing", a: "Playing ", b: s.title, two: playTime(s.gameId) + more }
        case "closing":
            return { glyph: "closing", a: "Closing…", b: "", two: s.title + more }
        case "notresponding":
            return { glyph: "warn", a: "Isn't responding", b: "", two: s.title + " · " + playTime(s.gameId) + more, warn: true }
        default:  // handoff, unconfirmed: Carthage can't follow it; the words say why
            return { glyph: "playing", a: "", b: s.title, two: s.statusText + more }
        }
    }
    // Keys: [label, width, enabled, action]
    readonly property var keys: {
        const s = sel
        if (!s) return []
        const id = s.gameId, st = s.state_
        const canSwitch = Backend.sessions.canSwitch(id) + 0 * tick
        const sw = ["Switch to Game", 132, !!canSwitch && st !== "closing", "switch"]
        if (st === "notresponding")
            return [sw, ["Force Quit", 98, true, "force"], ["Keep Waiting", 116, true, "wait"]]
        if (!s.tracked)
            return [sw, ["Eject", 64, st !== "closing", "eject"]]
        return [sw, ["Quit", 64, st === "running" || st === "starting", "quit"]]
    }
    function act(what) {
        const s = sel
        if (!s) return
        if (what === "switch") Backend.sessions.switchTo(s.gameId)
        else if (what === "quit") appRoot.confirmQuit(s.gameId, s.title, false)
        else if (what === "force") appRoot.confirmQuit(s.gameId, s.title, true)
        else if (what === "wait") Backend.sessions.keepWaiting(s.gameId)
        else if (what === "eject") Backend.sessions.eject(s.gameId)
    }

    // ── Widths (they animate, so the shell grows and shrinks from its centre) ──
    readonly property real keysW: keys.reduce((a, k) => a + k[1], 0) + Math.max(0, keys.length - 1) * 8
    readonly property real leftWTarget: (keys.length || status.two) ? 216 : 96
    readonly property real rightWTarget: keys.length ? keysW + 30 + 66 : 96
    readonly property real flatTarget: 88 + (bays - 1) * pitch
    property real leftW: leftWTarget
    property real rightW: rightWTarget
    property real flat: flatTarget
    Behavior on leftW { id: lb; NumberAnimation { duration: (lb.targetValue > dock.leftW ? 220 : 180) * dock.motion; easing.type: lb.targetValue > dock.leftW ? Easing.OutCubic : Easing.InCubic } }
    Behavior on rightW { id: rb; NumberAnimation { duration: (rb.targetValue > dock.rightW ? 220 : 180) * dock.motion; easing.type: rb.targetValue > dock.rightW ? Easing.OutCubic : Easing.InCubic } }
    Behavior on flat { id: fb; NumberAnimation { duration: (fb.targetValue > dock.flat ? 220 : 180) * dock.motion; easing.type: fb.targetValue > dock.flat ? Easing.OutCubic : Easing.InCubic } }
    readonly property real x0: pad + leftW + wingGap + curve
    readonly property real x1: x0 + flat
    width: x1 + curve + wingGap + rightW + pad

    // ── The shell ──
    readonly property string dip: "L " + (x0 - curve) + " 0 C " + (x0 - curve / 2) + " 0 " + (x0 - curve / 2) + " " + saddle + " " + x0 + " " + saddle
                                  + " L " + x1 + " " + saddle + " C " + (x1 + curve / 2) + " " + saddle + " " + (x1 + curve / 2) + " 0 " + (x1 + curve) + " 0"
    readonly property string shellPath: "M " + r + " 0 " + dip + " L " + (width - r) + " 0 A " + r + " " + r + " 0 0 1 " + width + " " + r
                                        + " L " + width + " " + (shellH - r) + " A " + r + " " + r + " 0 0 1 " + (width - r) + " " + shellH
                                        + " L " + r + " " + shellH + " A " + r + " " + r + " 0 0 1 0 " + (shellH - r) + " L 0 " + r
                                        + " A " + r + " " + r + " 0 0 1 " + r + " 0 Z"
    readonly property string topEdge: "M 0 " + r + " A " + r + " " + r + " 0 0 1 " + r + " 0 " + dip + " L " + (width - r) + " 0 A " + r + " " + r + " 0 0 1 " + width + " " + r
    readonly property string bottomEdge: "M 0 " + (shellH - r) + " A " + r + " " + r + " 0 0 0 " + r + " " + shellH + " L " + (width - r) + " " + shellH
                                         + " A " + r + " " + r + " 0 0 0 " + width + " " + (shellH - r)

    Shape {  // the shell's shape in white: the glass's mask
        id: shellMask
        visible: dock.glassy
        width: dock.width
        height: dock.shellH
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeWidth: -1; fillColor: "white"; PathSvg { path: dock.shellPath } }
    }
    GlassPane {
        visible: dock.glassy
        width: dock.width
        height: dock.shellH
        behind: dock.glassy ? dock.behind : []
        shape: shellMask
        blurPx: 26
        track: Qt.point(dock.x + 0 * dock.width, dock.y + dock.hideY + 0 * (dock.parent ? dock.parent.height : 0))
    }
    Item {  // plastic: the drop shadow (contact + ambient) under the shell
        visible: !dock.glassy
        width: dock.width
        height: dock.shellH
        Shape {
            id: shadowShape
            anchors.fill: parent
            visible: false
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: -1; fillColor: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.55 : 0.3); PathSvg { path: dock.shellPath } }
        }
        MultiEffect {
            source: shadowShape
            anchors.fill: parent
            y: 12
            blurEnabled: true
            blurMax: 16
            blur: 1
            autoPaddingEnabled: true
            opacity: 0.6
        }
    }
    Shape {  // the shell's surface
        width: dock.width
        height: dock.shellH
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: dock.shellH
                GradientStop { position: 0.0; color: dock.glassy ? Qt.tint(dock.g.tint, dock.g.sheen) : dock.pal.dockTop }
                GradientStop { position: 0.7; color: dock.glassy ? dock.g.tint : Qt.tint(dock.pal.dockTop, Qt.alpha(dock.pal.dockBottom, 0.7)) }
                GradientStop { position: 1.0; color: dock.glassy ? dock.g.tint : dock.pal.dockBottom }
            }
            PathSvg { path: dock.shellPath }
        }
        // The lit top contour, inside the shell (no outline elsewhere).
        ShapePath {
            fillColor: "transparent"
            strokeColor: dock.glassy ? dock.g.edge : Qt.alpha(dock.pal.dockHi, Backend.theme.dark ? 0.5 : 0.95)
            strokeWidth: 1.3
            PathSvg { path: dock.topEdge }
        }
        // Plastic: the shaded bottom contour.
        ShapePath {
            fillColor: "transparent"
            strokeColor: dock.glassy ? "transparent" : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.42 : 0.24)
            strokeWidth: 1.5
            PathSvg { path: dock.bottomEdge }
        }
    }

    // Glass: a soft plate under the words only, so the shell stays real glass (the handoff's
    // tint) while the text keeps ≥ 4.5:1 over the brightest art scrolling behind (measured).
    Item {
        id: textPlate
        visible: dock.glassy
        x: statusWing.x - 10
        y: Math.round((dock.shellH - 46) / 2)
        // It ends before the slot (running under it, it was cut off in a hard edge there).
        width: Math.min(dock.leftW + 10, 28 + Math.max(line1.implicitWidth, line2.visible ? line2.implicitWidth : 0) + 56)
        height: 46
        // Full strength under the words, fading out to the right; blurred so it has no edge —
        // a shadow under the words, not a box.
        Rectangle {
            id: plateShape
            anchors.fill: parent
            radius: 23
            visible: false
            readonly property color c: Backend.theme.dark ? Qt.rgba(0, 0, 0, 0.46) : Qt.rgba(1, 1, 1, 0.40)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: plateShape.c }
                GradientStop { position: Math.max(0.5, 1 - 44 / Math.max(1, textPlate.width)); color: plateShape.c }
                GradientStop { position: 1.0; color: Qt.alpha(plateShape.c, 0) }
            }
        }
        MultiEffect {
            source: plateShape
            anchors.fill: parent
            blurEnabled: true
            blurMax: 32
            blur: 1
            autoPaddingEnabled: true
        }
    }

    // ── Left wing: the status ──
    Item {
        id: statusWing
        x: dock.pad
        width: dock.leftW
        height: dock.shellH
        clip: true
        Accessible.role: Accessible.StatusBar
        Accessible.name: (dock.status.a + dock.status.b) + (dock.status.two ? ", " + dock.status.two : "")
        readonly property color ink: dock.glassy ? dock.g.text : dock.pal.dockText
        readonly property color ink2: dock.glassy ? dock.g.text2 : dock.pal.dockTextDim
        readonly property color warn: dock.glassy ? dock.g.warn : (Backend.theme.dark ? "#F2B544" : "#7A4E00")
        Item {  // the glyph
            id: glyph
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            readonly property string kind: dock.status.glyph
            readonly property color c: kind === "warn" ? statusWing.warn : statusWing.ink2
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {  // ring (ready: full; busy and closing: faint)
                    fillColor: "transparent"
                    strokeColor: glyph.kind === "ready" ? glyph.c : glyph.kind === "busy" || glyph.kind === "closing" ? Qt.alpha(glyph.c, 0.35) : "transparent"
                    strokeWidth: 1.6
                    PathAngleArc { centerX: 9; centerY: 9; radiusX: 5.8; radiusY: 5.8; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {  // busy: a quarter arc
                    fillColor: "transparent"
                    strokeColor: glyph.kind === "busy" ? glyph.c : "transparent"
                    strokeWidth: 1.6
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 9; centerY: 9; radiusX: 5.8; radiusY: 5.8; startAngle: -90; sweepAngle: 90 }
                }
                ShapePath {  // playing: a solid triangle
                    fillColor: glyph.kind === "playing" ? statusWing.ink : "transparent"
                    strokeWidth: -1
                    startX: 6.2; startY: 4.4
                    PathLine { x: 14; y: 9 }
                    PathLine { x: 6.2; y: 13.6 }
                    PathLine { x: 6.2; y: 4.4 }
                }
                ShapePath {  // warn: a triangle with a mark
                    fillColor: "transparent"
                    strokeColor: glyph.kind === "warn" ? statusWing.warn : "transparent"
                    strokeWidth: 1.6
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    startX: 9; startY: 2.8
                    PathLine { x: 15.8; y: 14.6 }
                    PathLine { x: 2.2; y: 14.6 }
                    PathLine { x: 9; y: 2.8 }
                    PathMove { x: 9; y: 7.2 }
                    PathLine { x: 9; y: 10.5 }
                }
            }
            Rectangle {  // closing: a square; warn: the dot
                visible: glyph.kind === "closing" || glyph.kind === "warn"
                x: glyph.kind === "closing" ? 6.6 : 8.4
                y: glyph.kind === "closing" ? 6.6 : 11.8
                width: glyph.kind === "closing" ? 4.8 : 1.2
                height: width
                radius: glyph.kind === "closing" ? 1 : 0.6
                color: glyph.c
            }
        }
        Column {
            id: words
            anchors.left: glyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            opacity: 1
            Text {
                id: line1
                width: parent.width
                textFormat: Text.StyledText
                text: Ui.escapeHtml(dock.status.a) + (dock.status.b ? "<b>" + Ui.escapeHtml(dock.status.b) + "</b>" : "")
                color: dock.status.warn ? statusWing.warn : statusWing.ink
                font.family: Ui.fontText
                font.weight: Font.Medium
                font.pixelSize: 14
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                elide: Text.ElideRight
            }
            Text {
                id: line2
                visible: text !== ""
                width: parent.width
                text: dock.status.two
                color: statusWing.ink2
                font.family: Ui.fontText
                font.pixelSize: 13  // (spec 12.5; pixel sizes are whole)
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
                elide: Text.ElideRight
            }
        }
        // A status change cross-fades (160 ms), no slide.
        property string key: dock.status.glyph + dock.status.a + dock.status.b
        onKeyChanged: if (dock.motion > 0) fade.restart()
        SequentialAnimation {
            id: fade
            NumberAnimation { target: words; property: "opacity"; to: 0.25; duration: 60 * dock.motion; easing.type: Easing.InQuad }
            NumberAnimation { target: words; property: "opacity"; to: 1; duration: 100 * dock.motion; easing.type: Easing.OutQuad }
        }
        HoverHandler { id: statusHover }
        QQC2.ToolTip.visible: statusHover.hovered && words.children[0].truncated
        QQC2.ToolTip.text: Accessible.name
    }

    // ── The bays ──
    Repeater {
        id: slots
        model: Backend.sessions
        delegate: DockSlot {
            required property var model
            required property int index
            appRoot: dock.appRoot
            dockItem: dock
            x: dock.bayX(index)
            width: 88
            gameId: model.gameId
            title: model.title
            state_: model.state
            statusText: model.statusText
            led: model.led
            source: model.source
            sourceName: model.sourceName
            sourceIcon: model.sourceIcon
            code: model.code
            extId: model.extId
            tracked: model.tracked
            several: dock.filled > 1
            selected: dock.sel === this
            Component.onCompleted: {
                if (!dock.appRoot.pendingSeat[gameId]) seatInstant()
                dock.select(gameId)
                Qt.callLater(dock.refreshActive)
            }
        }
    }
    DockSlot {
        empty: true
        visible: dock.filled === 0
        appRoot: dock.appRoot
        dockItem: dock
        x: dock.bayX(0)
        width: 88
    }

    // ── Right wing: keys, groove, clock ──
    Row {
        id: rightWing
        x: dock.x1 + dock.curve + dock.wingGap
        width: dock.rightW
        height: dock.shellH
        layoutDirection: Qt.RightToLeft
        clip: true
        Rectangle {  // the clock: a smoked window
            id: clockWin
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            width: Math.max(66, timeText.implicitWidth + 20)
            height: 34
            radius: 9
            gradient: Gradient {
                GradientStop { position: 0.0; color: dock.glassy ? dock.g.readout : "#111214" }
                GradientStop { position: 1.0; color: dock.glassy ? dock.g.readout : "#1C1D21" }
            }
            Rectangle {  // inner shadow at the top
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, dock.glassy ? 0.3 : 0.75) }
                    GradientStop { position: 0.12; color: "transparent" }
                }
            }
            Rectangle {  // ring
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: dock.glassy ? dock.g.ring : Qt.rgba(1, 1, 1, 0.07)
            }
            Item {  // the glint across its top
                anchors.fill: parent
                anchors.margins: 1
                anchors.bottomMargin: parent.height * 0.62
                clip: true
                Rectangle {
                    width: parent.width
                    height: parent.height + 4
                    radius: 8
                    color: Qt.rgba(1, 1, 1, dock.glassy ? 0.14 : 0.10)
                    rotation: -1.5
                }
            }
            property date now: new Date()
            Timer {
                interval: 10000
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: clockWin.now = new Date()
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: "Time " + timeText.text
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.locale().toString(clockWin.now, Qt.locale().timeFormat(Locale.ShortFormat))
                color: dock.glassy && !Backend.theme.dark ? dock.g.text : "#F4F5F7"
                font.family: Ui.fontText
                font.weight: Font.DemiBold
                font.pixelSize: 15
                font.letterSpacing: 0.75
                font.features: { "tnum": 1 }
            }
        }
        Item {  // the groove between the keys and the clock
            visible: dock.keys.length > 0
            width: 30
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                width: dock.glassy ? 1 : 2
                height: 30
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: dock.glassy ? dock.g.ring : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.42 : 0.24) }
                    GradientStop { position: 0.49; color: dock.glassy ? dock.g.ring : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.42 : 0.24) }
                    GradientStop { position: 0.5; color: dock.glassy ? dock.g.ring : Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.05 : 0.6) }
                    GradientStop { position: 1.0; color: dock.glassy ? dock.g.ring : Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.05 : 0.6) }
                }
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            spacing: 8
            layoutDirection: Qt.LeftToRight
            Repeater {
                model: dock.keys
                CButton {
                    required property var modelData
                    kind: "key"
                    width: modelData[1]
                    height: 36
                    text: modelData[0]
                    enabled: modelData[2] && (!dock.appRoot.modalOpen)
                    onClicked: dock.act(modelData[3])
                }
            }
        }
    }
}
