import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Shapes
import Carthage

Item {
    id: dock

    property Item appRoot
    // Floating (the sidebar layout concept): a rounded console base in the middle, no menu key
    // (Settings is in the sidebar); the window places it and shows it only when needed.
    property bool floating: false
    property real hideY: 0  // slid down out of sight by this much (the floating dock at rest)
    // The console base (the library's dock): sloped ends, raised shoulders and a valley in the
    // middle where the cartridges stand. The status sits on the left shoulder, a clock on the
    // right. The dock's own top is the valley floor; the shoulders rise above it.
    property bool valley: false
    readonly property real rise: valley ? 22 : 0      // shoulders above the valley floor
    readonly property real endRun: 40                 // the sloped ends
    readonly property real wallRun: 56                // the valley's walls
    readonly property real floorPad: 18               // floor beyond the outer slots
    readonly property real shoulderMin: 140
    readonly property real floorW: slotCount * slotW + 2 * floorPad
    // Centered when both shoulders fit; in a narrow window the valley moves right, so the status
    // (more important than the clock) keeps its room on the left.
    readonly property bool roomy: width >= 2 * (endRun + shoulderMin + wallRun) + floorW
    readonly property real valleyMid: roomy ? width / 2 : width - endRun - 20 - wallRun - floorW / 2
    readonly property real valleyL: Math.round(valleyMid - floorW / 2) - wallRun  // the left wall's top
    readonly property real valleyR: Math.round(valleyMid + floorW / 2) + wallRun  // the right wall's top

    readonly property var pal: Backend.theme.p
    readonly property real motion: appRoot ? appRoot.motion : 1

    readonly property real cartW: 84
    readonly property real cartH: cartW * Backend.theme.ratio
    readonly property real lipY: 39
    readonly property real protrude: 75 // how much cartridge shows above the lip
    readonly property real riseHeight: cartH - protrude + 12 // travel to fully clear the lip
    readonly property int filled: Backend.sessions.count
    // One slot per docked game, or one empty slot while nothing is docked.
    readonly property int slotCount: Math.max(1, filled)
    // Floating, the status takes the left part (statusRoom) and the slots line up after it.
    readonly property real statusRoom: 320
    readonly property real slotW: valley
        ? Math.min(156, Math.max(84, (width - 2 * (endRun + wallRun + floorPad) - shoulderMin - 20) / slotCount))
        : Math.min(156, (floating ? Math.max(slotCount * 84, width - statusRoom) : width) / slotCount)

    // Slots slide only while one is added or removed, not while the window is resized (they'd
    // lag behind the edge).
    property bool slotsMoving: false
    onFilledChanged: {
        slotsMoving = true
        slotsMovingTimer.restart()
    }
    Timer {
        id: slotsMovingTimer
        interval: 250 * Math.max(dock.motion, 0.01) + 50
        onTriggered: dock.slotsMoving = false
    }

    signal clicked()

    height: 70

    function slotX(i) {
        if (valley) return Math.round(valleyMid - slotCount * slotW / 2 + i * slotW)
        if (floating) return Math.round(width - 12 - slotCount * slotW + i * slotW)
        return Math.round((width - slotCount * slotW) / 2 + i * slotW)
    }
    function seatPos(i) {
        return Qt.point(slotX(i) + Math.round((slotW - cartW) / 2), lipY - protrude)
    }
    function slotFor(gameId) {
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i)
            if (s && s.gameId === gameId) return s
        }
        return null
    }
    function focusFirst() {
        const s = slots.itemAt(0)
        if (s) s.forceActiveFocus()
    }
    function bump() {
        if (motion > 0) bumpAnim.restart()
    }

    property real bumpY: 0
    SequentialAnimation {
        id: bumpAnim
        NumberAnimation { target: dock; property: "bumpY"; to: 2; duration: 40 * dock.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: dock; property: "bumpY"; to: 0; duration: 80 * dock.motion; easing.type: Easing.OutBack }
    }
    transform: Translate { y: dock.bumpY + dock.hideY }

    Plastic {
        visible: !dock.valley
        anchors.fill: parent
        anchors.bottomMargin: dock.floating ? 0 : -4 // hide the bump gap at the window's bottom edge
        radius: dock.floating ? 22 : 0
        border.width: dock.floating ? 1 : 0
        border.color: dock.pal.dockSeam
    }

    // The console base's body: one plastic shape, lit from the top left (a thin highlight runs
    // along its top edge, a seam line just outside it), with the plastic's grain.
    Item {
        id: base
        visible: dock.valley
        x: 0
        y: -dock.rise
        width: dock.width
        height: dock.height + dock.rise + 4   // past the window's bottom edge (the bump)
        readonly property real shoulderY: 0            // the shoulders
        readonly property real floorY: dock.rise       // the valley floor
        readonly property real baseBottom: height
        readonly property real baseW: width
        Shape {
            id: bodyShape
            anchors.fill: parent
            layer.enabled: true      // also the grain's mask
            layer.samples: 4
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: base.height
                    GradientStop { position: 0; color: dock.pal.dockTop }
                    GradientStop { position: 1; color: dock.pal.dockBottom }
                }
                startX: 0; startY: base.baseBottom
                // "/": the left end rises to the shoulder
                PathCubic {
                    x: dock.endRun; y: base.shoulderY
                    control1X: dock.endRun * 0.42; control1Y: base.baseBottom * 0.15
                    control2X: dock.endRun * 0.6; control2Y: base.shoulderY
                }
                PathLine { x: dock.valleyL; y: base.shoulderY }
                // down into the valley
                PathCubic {
                    x: dock.valleyL + dock.wallRun; y: base.floorY
                    control1X: dock.valleyL + dock.wallRun * 0.55; control1Y: base.shoulderY
                    control2X: dock.valleyL + dock.wallRun * 0.45; control2Y: base.floorY
                }
                PathLine { x: dock.valleyR - dock.wallRun; y: base.floorY }
                // and up again
                PathCubic {
                    x: dock.valleyR; y: base.shoulderY
                    control1X: dock.valleyR - dock.wallRun * 0.45; control1Y: base.floorY
                    control2X: dock.valleyR - dock.wallRun * 0.55; control2Y: base.shoulderY
                }
                PathLine { x: base.baseW - dock.endRun; y: base.shoulderY }
                // "\": the right end falls away
                PathCubic {
                    x: base.baseW; y: base.baseBottom
                    control1X: base.baseW - dock.endRun * 0.6; control1Y: base.shoulderY
                    control2X: base.baseW - dock.endRun * 0.42; control2Y: base.baseBottom * 0.15
                }
                PathLine { x: 0; y: base.baseBottom }
            }
        }
        // The grain, only on the body.
        Image {
            id: baseGrain
            anchors.fill: parent
            source: "image://gc/grain/" + Backend.theme.edition + Backend.theme.texQuery
            fillMode: Image.Tile
            smooth: false
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: baseGrain
            opacity: 0.35
            maskEnabled: true
            maskSource: bodyShape
        }
        // The top edge: a seam just outside, a highlight just inside (the light catches it).
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                id: edge
                fillColor: "transparent"
                strokeColor: dock.pal.dockSeam
                strokeWidth: 1
                startX: 0; startY: base.baseBottom
                PathCubic { x: dock.endRun; y: base.shoulderY; control1X: dock.endRun * 0.42; control1Y: base.baseBottom * 0.15; control2X: dock.endRun * 0.6; control2Y: base.shoulderY }
                PathLine { x: dock.valleyL; y: base.shoulderY }
                PathCubic { x: dock.valleyL + dock.wallRun; y: base.floorY; control1X: dock.valleyL + dock.wallRun * 0.55; control1Y: base.shoulderY; control2X: dock.valleyL + dock.wallRun * 0.45; control2Y: base.floorY }
                PathLine { x: dock.valleyR - dock.wallRun; y: base.floorY }
                PathCubic { x: dock.valleyR; y: base.shoulderY; control1X: dock.valleyR - dock.wallRun * 0.45; control1Y: base.floorY; control2X: dock.valleyR - dock.wallRun * 0.55; control2Y: base.shoulderY }
                PathLine { x: base.baseW - dock.endRun; y: base.shoulderY }
                PathCubic { x: base.baseW; y: base.baseBottom; control1X: base.baseW - dock.endRun * 0.6; control1Y: base.shoulderY; control2X: base.baseW - dock.endRun * 0.42; control2Y: base.baseBottom * 0.15 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: dock.pal.dockHi
                strokeWidth: 1.5
                startX: 1.5; startY: base.baseBottom
                PathCubic { x: dock.endRun; y: base.shoulderY + 1.5; control1X: dock.endRun * 0.42 + 1; control1Y: base.baseBottom * 0.15; control2X: dock.endRun * 0.6; control2Y: base.shoulderY + 1.5 }
                PathLine { x: dock.valleyL; y: base.shoulderY + 1.5 }
                PathCubic { x: dock.valleyL + dock.wallRun; y: base.floorY + 1.5; control1X: dock.valleyL + dock.wallRun * 0.55; control1Y: base.shoulderY + 1.5; control2X: dock.valleyL + dock.wallRun * 0.45; control2Y: base.floorY + 1.5 }
                PathLine { x: dock.valleyR - dock.wallRun; y: base.floorY + 1.5 }
                PathCubic { x: dock.valleyR; y: base.shoulderY + 1.5; control1X: dock.valleyR - dock.wallRun * 0.45; control1Y: base.floorY + 1.5; control2X: dock.valleyR - dock.wallRun * 0.55; control2Y: base.shoulderY + 1.5 }
                PathLine { x: base.baseW - dock.endRun; y: base.shoulderY + 1.5 }
                PathCubic { x: base.baseW - 1.5; y: base.baseBottom; control1X: base.baseW - dock.endRun * 0.6; control1Y: base.shoulderY + 1.5; control2X: base.baseW - dock.endRun * 0.42 - 1; control2Y: base.baseBottom * 0.15 }
            }
        }
    }

    // The clock on the right shoulder (time in the desktop's own 12/24-hour style).
    Column {
        id: clock
        visible: dock.valley && (dock.width - dock.endRun - 14) - (dock.valleyR + 12) >= width
        anchors.right: parent.right
        anchors.rightMargin: dock.endRun + 14
        y: Math.round((dock.height - dock.rise) / 2 - height / 2)
        property date now: new Date()
        Timer {
            interval: 10000
            repeat: true
            running: clock.visible
            triggeredOnStart: true
            onTriggered: clock.now = new Date()
        }
        Accessible.role: Accessible.StaticText
        Accessible.name: timeText.text + ", " + dateText.text
        Text {
            id: timeText
            anchors.right: parent.right
            text: Qt.locale().toString(clock.now, Qt.locale().timeFormat(Locale.ShortFormat))
            color: dock.pal.dockText
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
            font.letterSpacing: 1
        }
        Text {
            id: dateText
            anchors.right: parent.right
            text: Qt.locale("en_GB").toString(clock.now, "ddd d MMM")
            color: dock.pal.dockTextDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
        }
    }

    property Item activeSlot: null
    readonly property var installing: {
        const p = Backend.installs ? Backend.installs.progress : ({})
        const ids = Object.keys(p)
        if (!ids.length) return null
        return { title: Backend.titleOf(ids[0]) || "a game", progress: p[ids[0]], more: ids.length - 1 }
    }
    function refreshActive() {
        let hovered = null, attention = null, last = null
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i)
            if (!s || s.state_ === "ended") continue
            if (s.hovered || s.activeFocus) hovered = s
            if (s.state_ === "notresponding") attention = s
            last = s
        }
        activeSlot = hovered || attention || last
    }
    Connections {
        target: Backend.sessions
        function onDataChanged() { dock.refreshActive() }
        function onCountChanged() { Qt.callLater(dock.refreshActive) }
    }

    // The status line follows the slot under the pointer or keyboard focus; otherwise the game
    // that needs attention, else the most recent one.
    Item {
        id: display
        readonly property color ink: dock.pal.dockText
        readonly property color inkDim: dock.pal.dockTextDim
        readonly property Item s: dock.activeSlot
        readonly property real room: dock.valley ? dock.valleyL - (dock.endRun + 14) - 12
                                   : dock.floating ? dock.slotX(0) - 20 - Ui.gapL
                                   : (dock.width - dock.slotCount * dock.slotW) / 2 - 2 * Ui.gapXL
        readonly property var inst: dock.installing
        readonly property bool gettingArt: !s && !inst && !!Backend.artPicker && Backend.artPicker.pending > 0
        readonly property color ledColor: dock.appRoot && !dock.appRoot.powered ? dock.pal.ledOff
                                        : !s ? (inst || gettingArt ? Backend.theme.led.amber
                                                  : Backend.theme.led.green)
                                            : s.led === "green" ? Backend.theme.led.green : Backend.theme.led.amber
        readonly property string main: !s ? (inst ? "Installing " + inst.title : "Ready")
                                     : s.state_ === "notresponding" ? s.title + " isn't responding"
                                     : s.title
        readonly property string detail: {
            if (!s) {
                if (inst) return Math.round(inst.progress * 100) + "%" + (inst.more ? ", and " + inst.more + " more" : "")
                if (gettingArt) return "getting art, " + Backend.artPicker.pending + " left"
                return ""  // at rest: just "Ready"
            }
            const d = s.state_ === "notresponding" ? "click the cartridge" : s.statusText
            return dock.filled > 1 ? d + " · " + dock.filled + " running" : d
        }
        visible: room >= 120
        x: dock.valley ? dock.endRun + 14 : 20
        // On the console base: two lines (the name, then what it's doing), centered on the
        // shoulder like the clock opposite.
        y: dock.valley ? Math.round((dock.height - dock.rise) / 2 - (detail ? 18 : 10))
                       : Math.round(dock.lipY - height / 2) - 2
        width: dock.valley ? room : Math.min(420, room)
        height: 20
        Accessible.role: Accessible.StaticText
        Accessible.name: detail ? main + ", " + detail : main

        Led {
            id: statusLed
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            color: display.ledColor
            // A busy blink at 2 Hz, under the 3 Hz flashing limit.
            SequentialAnimation {
                running: display.gettingArt && Backend.motion > 0
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: statusLed.light; property: "opacity"; to: 0.2; duration: 70; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 180 }
                NumberAnimation { target: statusLed.light; property: "opacity"; to: 1; duration: 70; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 180 }
            }
        }
        Text {
            id: statusText
            anchors.left: statusLed.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            text: "<b>" + Ui.escapeHtml(display.main) + "</b>"
                  + (display.detail && !dock.valley ? "<font color=\"" + display.inkDim + "\">  ·  " + Ui.escapeHtml(display.detail) + "</font>" : "")
            color: display.ink
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            elide: Text.ElideRight
            HoverHandler { id: statusHover }
            QQC2.ToolTip.visible: statusHover.hovered && statusText.truncated
            QQC2.ToolTip.text: display.detail ? display.main + " · " + display.detail : display.main
        }
        Text {
            visible: dock.valley && display.detail !== ""
            x: statusText.x
            y: 20
            width: display.width - x
            text: display.detail
            color: display.inkDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
            elide: Text.ElideRight
        }
    }

    Item {
        id: menuKey
        visible: !dock.floating && !dock.valley
        anchors.right: parent.right
        anchors.rightMargin: 23
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 2
        width: 52
        height: 40
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Menu"
        Keys.onReturnPressed: dock.appRoot.toggleDrawer()
        Keys.onSpacePressed: dock.appRoot.toggleDrawer()

        readonly property bool down: keyTap.pressed
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: 12
            color: Qt.darker(dock.pal.dockBottom, Backend.theme.dark ? 1.3 : 1.1)
        }
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: menuKey.down ? 2 : 0
            anchors.bottomMargin: menuKey.down ? 0 : 2
            radius: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: menuHover.hovered ? Qt.lighter(dock.pal.dockTop, 1.04) : dock.pal.dockTop }
                GradientStop { position: 1.0; color: dock.pal.dockBottom }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.18)
            CIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: "application-menu-symbolic"
                isMask: true
                color: dock.pal.dockText
            }
        }
        Rectangle {
            visible: menuKey.activeFocus
            anchors.fill: parent
            anchors.margins: -5
            radius: 14
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
        HoverHandler { id: menuHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: keyTap
            onPressedChanged: if (pressed) dock.appRoot.sound("key")
            onTapped: dock.appRoot.toggleDrawer()
        }
    }

    Rectangle {
        visible: !dock.floating && !dock.valley
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: dock.pal.dockSeam
    }
    Rectangle {
        visible: !dock.floating && !dock.valley
        anchors.left: parent.left
        anchors.right: parent.right
        y: 1
        height: 1
        color: dock.pal.dockHi
    }
    Rectangle {
        visible: !dock.floating && !dock.valley
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.12) }
        }
    }

    Repeater {
        id: slots
        model: Backend.sessions
        delegate: DockSlot {
            required property var model
            required property int index
            appRoot: dock.appRoot
            dockItem: dock
            x: dock.slotX(index)
            width: dock.slotW
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
            Behavior on x {
                enabled: dock.slotsMoving
                NumberAnimation { duration: 200 * dock.motion; easing.type: Easing.InOutCubic }
            }
            onHoveredChanged: dock.refreshActive()
            onActiveFocusChanged: dock.refreshActive()
            Component.onCompleted: {
                if (!dock.appRoot.pendingSeat[gameId]) seatInstant()
                Qt.callLater(dock.refreshActive)
            }
        }
    }

    DockSlot {
        empty: true
        visible: dock.filled === 0
        appRoot: dock.appRoot
        dockItem: dock
        x: dock.slotX(0)
        width: dock.slotW
        Behavior on x {
            enabled: dock.slotsMoving
            NumberAnimation { duration: 200 * dock.motion; easing.type: Easing.InOutCubic }
        }
    }
}
