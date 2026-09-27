import QtQuick
import QtQuick.Controls as QQC2
import Carthage

Item {
    id: dock

    property Item appRoot

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
    readonly property real slotW: Math.min(156, width / slotCount)

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
    transform: Translate { y: dock.bumpY }

    Plastic {
        anchors.fill: parent
        anchors.bottomMargin: -4 // hide the bump gap at the window's bottom edge
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
    Display {
        id: display
        readonly property Item s: dock.activeSlot
        readonly property real room: (dock.width - dock.slotCount * dock.slotW) / 2 - 2 * Ui.gapXL
        readonly property var inst: dock.installing
        readonly property bool gettingArt: !s && !inst && !!Backend.artPicker && Backend.artPicker.pending > 0
        readonly property color ledColor: dock.appRoot && !dock.appRoot.powered ? dock.pal.ledOff
                                        : !s ? (inst || gettingArt ? Backend.theme.led.amber
                                                  : Backend.status.steamRunning ? Backend.theme.led.green : dock.pal.ledOff)
                                            : s.led === "green" ? Backend.theme.led.green : Backend.theme.led.amber
        readonly property string main: !s ? (inst ? "Installing " + inst.title
                                                  : Backend.status.steamRunning ? "Steam is on" : "Steam is off")
                                     : s.state_ === "notresponding" ? s.title + " isn't responding"
                                     : s.title
        readonly property string detail: {
            if (!s) {
                if (inst) return Math.round(inst.progress * 100) + "%" + (inst.more ? ", and " + inst.more + " more" : "")
                if (gettingArt) return "getting art, " + Backend.artPicker.pending + " left"
                return Backend.status.total + " games, " + Backend.status.installed + " installed"
            }
            const d = s.state_ === "notresponding" ? "click the cartridge" : s.statusText
            return dock.filled > 1 ? d + " · " + dock.filled + " running" : d
        }
        visible: room >= (bare ? 120 : 140)
        x: bare ? 20 : 24  // the window's side margin (a bezel reaches the 20 px margin)
        y: Math.round(dock.lipY - height / 2) - 2
        width: Math.min(bare ? 420 : 280, room)
        height: bare ? 20 : 30
        Accessible.role: Accessible.StaticText
        Accessible.name: main + ", " + detail

        Led {
            id: statusLed
            x: display.bare ? 0 : 10
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
            anchors.leftMargin: display.bare ? 10 : 8
            anchors.right: parent.right
            anchors.rightMargin: display.bare ? 0 : 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: display.vfd ? 1 : 0
            textFormat: Text.StyledText
            text: display.bare
                  ? "<b>" + display.main.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</b>"
                    + "<font color=\"" + display.inkDim + "\">  ·  " + display.detail.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>"
                  : display.main.toUpperCase().replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    + "<font color=\"" + display.inkDim + "\"> · " + display.detail.toUpperCase().replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>"
            color: display.ink
            font.family: display.fontFamily
            font.pixelSize: display.bare ? Ui.textBody : display.fontPx(12)
            font.letterSpacing: display.bare ? 0 : 0.4
            elide: Text.ElideRight
            HoverHandler { id: statusHover }
            QQC2.ToolTip.visible: statusHover.hovered && statusText.truncated
            QQC2.ToolTip.text: display.main + " · " + display.detail
        }
    }

    Item {
        id: menuKey
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
        readonly property bool hot: Backend.theme.skin === "hifi"
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
                GradientStop { position: 0.0; color: menuKey.hot ? (menuHover.hovered ? "#ff9a5c" : "#ff8a45") : (menuHover.hovered ? Qt.lighter(dock.pal.dockTop, 1.04) : dock.pal.dockTop) }
                GradientStop { position: 1.0; color: menuKey.hot ? "#d24d06" : dock.pal.dockBottom }
            }
            border.width: 1
            border.color: menuKey.hot ? "#8c3300" : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.18)
            CIcon {
                visible: !menuKey.hot
                anchors.centerIn: parent
                width: 20
                height: 20
                source: "application-menu-symbolic"
                isMask: true
                color: dock.pal.dockText
            }
            Text {
                visible: menuKey.hot
                anchors.centerIn: parent
                text: "MENU"
                color: "#ffffff"
                font.family: "Barlow Condensed"
                font.weight: Font.Bold
                font.pixelSize: 12
                font.letterSpacing: 2
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: dock.pal.dockSeam
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: 1
        height: 1
        color: dock.pal.dockHi
    }
    Rectangle {
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
