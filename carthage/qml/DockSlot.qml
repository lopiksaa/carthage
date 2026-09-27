// One dock slot and its cartridge. The empty slot uses the same component with `empty: true`.
import QtQuick
import Carthage

Item {
    id: slot

    property bool empty: false
    property string gameId
    property string title
    property string state_
    property string statusText
    property string led: "off"
    property string source
    property string sourceName
    property string sourceIcon
    property string code
    property string extId
    property bool tracked: true

    property Item appRoot
    property Item dockItem

    readonly property var pal: Backend.theme.p
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property real cartW: dockItem.cartW
    readonly property real innerX: Math.round((width - cartW) / 2) // opening centered in the slot
    readonly property real lipY: dockItem.lipY

    property bool seated: false
    property real seatOffset: 0
    property real pressOffset: (state_ === "closing" || state_ === "notresponding") ? 4 : 0
    Behavior on pressOffset {
        NumberAnimation { duration: 100 * slot.motion; easing.type: Easing.OutCubic }
    }
    property real hoverOffset: hover.hovered && seated && seatOffset === 0 ? -2 : 0
    Behavior on hoverOffset {
        NumberAnimation { duration: 100 * slot.motion; easing.type: Easing.OutCubic }
    }
    property real nudgeX: 0

    height: dockItem.height
    activeFocusOnTab: !empty
    Accessible.role: empty ? Accessible.StaticText : Accessible.Button
    Accessible.name: empty ? "Empty slot. Choose a game" : title + ", " + statusText
    Accessible.onPressAction: openMenu()

    function seatIn() {
        seated = true
        if (motion <= 0) {
            seatOffset = 0
            dockItem.clicked()
            return
        }
        seatOffset = -dockItem.riseHeight
        seatAnim.restart()
    }
    function seatInstant() {
        seated = true
        seatOffset = 0
    }
    // `done` gets the risen card's top-left.
    function riseOut(done) {
        riseAnim.onDone = done
        riseAnim.restart()
    }
    function cartTopLeft(item) {
        return cartHolder.mapToItem(item, cart.x, cart.y)
    }
    function nudge() {
        if (motion > 0) nudgeAnim.restart()
    }
    function openMenu() {
        if (!empty) appRoot.openSlotPanel(slot)
    }
    readonly property bool hovered: hover.hovered

    readonly property real contactOffset: -(dockItem.riseHeight - 12)
    SequentialAnimation {
        id: seatAnim
        NumberAnimation { target: slot; property: "seatOffset"; to: slot.contactOffset; duration: 100 * slot.motion; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: slot; property: "seatOffset"; to: -3; duration: 190 * slot.motion; easing.type: Easing.OutQuad }
            SequentialAnimation {
                NumberAnimation { target: slot; property: "nudgeX"; to: 0.8; duration: 60 * slot.motion }
                NumberAnimation { target: slot; property: "nudgeX"; to: -0.6; duration: 70 * slot.motion }
                NumberAnimation { target: slot; property: "nudgeX"; to: 0; duration: 60 * slot.motion }
            }
        }
        NumberAnimation { target: slot; property: "seatOffset"; to: 2; duration: 50 * slot.motion; easing.type: Easing.InQuad }
        ScriptAction { script: { slot.dockItem.clicked(); slot.boot() } }
        NumberAnimation { target: slot; property: "seatOffset"; to: 0; duration: 140 * slot.motion; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        id: riseAnim
        property var onDone
        NumberAnimation { target: slot; property: "seatOffset"; to: 2; duration: 60 * slot.motion; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: slot; property: "seatOffset"; to: -slot.dockItem.riseHeight
            duration: 260 * slot.motion; easing.type: Easing.OutBack; easing.overshoot: 1.2
        }
        ScriptAction { script: if (riseAnim.onDone) riseAnim.onDone() }
    }
    property bool booting: false
    function boot() {
        if (motion > 0) bootAnim.restart()
    }
    SequentialAnimation {
        id: bootAnim
        PropertyAction { target: slot; property: "booting"; value: true }
        PauseAnimation { duration: 70 }
        PropertyAction { target: slot; property: "booting"; value: false }
        PauseAnimation { duration: 60 }
        PropertyAction { target: slot; property: "booting"; value: true }
        PauseAnimation { duration: 110 }
        PropertyAction { target: slot; property: "booting"; value: false }
    }
    SequentialAnimation {
        id: nudgeAnim
        NumberAnimation { target: slot; property: "nudgeX"; to: -3; duration: 40 * slot.motion }
        NumberAnimation { target: slot; property: "nudgeX"; to: 3; duration: 60 * slot.motion }
        NumberAnimation { target: slot; property: "nudgeX"; to: 0; duration: 40 * slot.motion }
    }

    // Drawn in three layers so a docked cartridge sits inside the port: the housing and opening
    // behind it, the cartridge, then the port's front lip over its lower edge. open_ goes 0 → 1
    // as the cartridge pushes the flaps open.
    readonly property real open_: !seated || empty ? 0
                                  : Math.max(0, Math.min(1, (seatOffset - contactOffset) / 16))
    readonly property bool dark: Backend.theme.dark
    readonly property real mouthX: innerX - 1
    readonly property real mouthW: cartW + 2
    readonly property real mouthTop: lipY - 7
    readonly property real lipTop: lipY - 2
    // Opaque, so the front lip can continue the same gradient over the cartridge.
    readonly property color frameTop: Qt.lighter(pal.dockTop, dark ? 1.12 : 1.0)
    readonly property color frameBottom: Qt.darker(pal.dockBottom, dark ? 1.12 : 1.06)
    readonly property color plasticDeep: Qt.darker(pal.dockBottom, dark ? 1.5 : 1.12)

    Rectangle {
        x: slot.mouthX - 16
        y: slot.mouthTop - 7
        width: slot.mouthW + 32
        height: slot.lipY + 13 - y
        radius: 7
        color: Qt.darker(slot.frameBottom, 1.2)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, slot.dark ? 0.5 : 0.2)
    }
    Rectangle {
        id: portFace
        x: slot.mouthX - 15
        y: slot.mouthTop - 6
        width: slot.mouthW + 30
        height: slot.lipY + 7 - y
        radius: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: slot.frameTop }
            GradientStop { position: 1.0; color: slot.frameBottom }
        }
        Rectangle {
            x: parent.radius
            y: 1
            width: parent.width - 2 * parent.radius
            height: 1
            color: slot.pal.dockHi
        }
    }
    Rectangle {
        x: slot.mouthX
        y: slot.mouthTop
        width: slot.mouthW
        height: slot.lipTop - slot.mouthTop + 1
        radius: 2
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2a2a2e" }
            GradientStop { position: 0.4; color: "#0d0d10" }
            GradientStop { position: 1.0; color: "#040405" }
        }
        Rectangle {
            width: parent.width
            height: parent.height * (1 - slot.open_)
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(slot.plasticDeep, 1.4) }
                GradientStop { position: 1.0; color: slot.plasticDeep }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.6)
            }
        }
    }

    Item {
        id: cartHolder
        x: slot.innerX - 30
        y: -400
        width: slot.cartW + 60
        height: 400 + slot.lipY - 2
        clip: true

        Cartridge {
            id: cart
            visible: slot.seated && !slot.empty
            x: 30 + slot.nudgeX
            y: 400 + slot.lipY - slot.dockItem.protrude + slot.seatOffset + slot.pressOffset + slot.hoverOffset
            width: slot.cartW
            gameId: slot.gameId
            title: slot.title
            source: slot.source
            sourceName: slot.sourceName
            sourceIcon: slot.sourceIcon
            code: slot.code
            extId: slot.extId

            Rectangle {
                visible: slot.activeFocus
                anchors.fill: parent
                anchors.margins: -4
                radius: Backend.theme.geo.radius * cart.u + 4
                color: "transparent"
                border.width: 3
                border.color: Ui.focusColor
            }
        }
    }

    Rectangle {
        id: portLip
        readonly property real from: (slot.lipTop - portFace.y) / portFace.height
        x: portFace.x + 1
        y: slot.lipTop
        width: portFace.width - 2
        height: portFace.y + portFace.height - 1 - slot.lipTop
        radius: portFace.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.tint(slot.frameTop, Qt.rgba(slot.frameBottom.r, slot.frameBottom.g, slot.frameBottom.b, portLip.from)) }
            GradientStop { position: 1.0; color: slot.frameBottom }
        }
        Rectangle {  // the lip's edge, lit from above
            x: 3
            width: parent.width - 6
            height: 1
            color: slot.pal.dockHi
            opacity: 0.8
        }
    }

    Item {
        visible: !slot.empty && slot.seated
        x: slot.innerX
        y: slot.lipY - slot.dockItem.protrude
        width: slot.cartW
        height: slot.dockItem.protrude

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        // Exclusive grabs: a tap on a docked cartridge must never also reach the cards
        // behind it (the default, shared grab would pass it on).
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            enabled: !slot.appRoot.modalOpen || slot.appRoot.slotPanelFor(slot)
            onTapped: slot.appRoot.slotPanelFor(slot) ? slot.appRoot.closeSlotPanel() : slot.openMenu()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            enabled: !slot.appRoot.modalOpen || slot.appRoot.slotPanelFor(slot)
            onTapped: slot.appRoot.slotPanelFor(slot) ? slot.appRoot.closeSlotPanel() : slot.openMenu()
        }
    }

    Keys.onReturnPressed: openMenu()
    Keys.onEnterPressed: openMenu()
    Keys.onSpacePressed: openMenu()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            openMenu()
            event.accepted = true
        }
    }

    // The status line spells out what the LED means, so color is never the only cue.
    Led {
        id: ledItem
        visible: !slot.empty
        anchors.horizontalCenter: parent.horizontalCenter
        y: slot.lipY + 12
        size: 7
        fade: 0  // the boot flicker is sharp
        color: slot.booting ? Backend.theme.led.amber
             : slot.led === "green" ? Backend.theme.led.green
             : slot.led === "amber" ? Backend.theme.led.amber : slot.pal.ledOff
        readonly property bool pulsing: slot.state_ === "starting" || slot.state_ === "closing"
        readonly property bool active: slot.state_ === "running" || slot.state_ === "handoff"

        SequentialAnimation {
            running: ledItem.pulsing && slot.motion > 0
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { target: ledItem.light; property: "opacity"; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { target: ledItem.light; property: "opacity"; to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
        Timer {
            running: ledItem.active && slot.motion > 0
            repeat: true
            interval: 3000
            onTriggered: {
                interval = 3000 + Math.random() * 4000
                blink.restart()
            }
        }
        SequentialAnimation {
            id: blink
            NumberAnimation { target: ledItem.light; property: "opacity"; to: 0.7; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: ledItem.light; property: "opacity"; to: 1; duration: 420; easing.type: Easing.InOutSine }
        }
    }
}
