// One bay of the dock: the slot's mouth (flaps shut when empty), the docked mini cartridge
// clipped at the slot line, and the front lip over it (design handoff, Spec §5). The empty bay
// uses the same component with `empty: true`. The bay is `width` wide; the mouth is centred.
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
    property bool selected: false
    property bool several: false          // two or more games in the dock

    readonly property var pal: Backend.theme.p
    readonly property var g: Backend.theme.glass
    readonly property bool glassy: Backend.theme.glassy
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property real cartW: dockItem.cartW
    readonly property real cartH: dockItem.cartH
    readonly property real slotLine: dockItem.lipY        // the cartridge is cut off here
    readonly property real mouthY: dockItem.saddle - 2

    // How much of the cartridge shows above the slot line (Spec §5 "Visible above slot").
    property bool seated: false
    property real lift: 0                 // extra rise while ejecting
    readonly property real visibleTarget: state_ === "closing" ? 52
                                        : several ? (selected ? 46 : 34) : 40
    // A flight lands with the whole cartridge above the slot line; seating slides it in.
    property real shown: cartH
    property bool instant: false
    Behavior on shown {
        enabled: slot.seated && !slot.instant && !seatAnim.running
        NumberAnimation { duration: 100 * slot.motion; easing.type: Easing.OutCubic }
    }
    Binding on shown { value: slot.visibleTarget; when: slot.seated && slot.lift === 0 && !seatAnim.running }
    property real nudgeX: 0

    height: dockItem.height
    activeFocusOnTab: !empty
    Accessible.role: empty ? Accessible.StaticText : Accessible.Button
    Accessible.name: empty ? "Empty slot. Choose a game" : title + ", " + statusText
    Accessible.onPressAction: openMenu()

    // Flaps: shut when nothing is in the slot, open while a cartridge is in it.
    property bool arriving: false         // a flight is about to land (flaps open at 70 % of it)
    property real open_: (seated || arriving) && !empty ? 1 : 0
    Behavior on open_ {
        NumberAnimation { duration: (slot.open_ > 0.5 ? 140 : 120) * slot.motion; easing.type: slot.open_ > 0.5 ? Easing.InCubic : Easing.OutCubic }
    }

    // Seating (the old insert, Sam's pick): it touches the flaps, pushes in with a slight side
    // wiggle, sinks a hair past its seat, clicks, and settles with a small bounce.
    function seatIn() {
        if (motion <= 0) {
            seated = true
            appRoot.sound("insert")
            return
        }
        seatAnim.target_ = visibleTarget
        seated = true
        appRoot.sound("insert")  // (Sam: the eject sound, a little quicker, fits going in)
        seatAnim.restart()
    }
    SequentialAnimation {
        id: seatAnim
        property real target_: 62
        NumberAnimation { target: slot; property: "shown"; to: seatAnim.target_ + 10; duration: 100 * slot.motion; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: slot; property: "shown"; to: seatAnim.target_ + 1; duration: 190 * slot.motion; easing.type: Easing.OutQuad }
            SequentialAnimation {
                NumberAnimation { target: slot; property: "nudgeX"; to: 0.8; duration: 60 * slot.motion }
                NumberAnimation { target: slot; property: "nudgeX"; to: -0.6; duration: 70 * slot.motion }
                NumberAnimation { target: slot; property: "nudgeX"; to: 0; duration: 60 * slot.motion }
            }
        }
        NumberAnimation { target: slot; property: "shown"; to: seatAnim.target_ - 2; duration: 50 * slot.motion; easing.type: Easing.InQuad }
        ScriptAction { script: slot.dockItem.nudgeShell() }  // (the insert sound already played)
        NumberAnimation { target: slot; property: "shown"; to: seatAnim.target_; duration: 140 * slot.motion; easing.type: Easing.OutBack }
    }
    function seatInstant() {
        instant = true
        seated = true
        shown = visibleTarget
        instant = false
    }
    // Eject: the cartridge lifts out (ease-in), then `done` gets its top-left.
    function riseOut(done) {
        riseAnim.onDone = done
        if (motion <= 0) {
            lift = 1
            done()
            return
        }
        riseAnim.restart()
    }
    function cartTopLeft(item) {
        return cart.mapToItem(item, 0, 0)
    }
    function nudge() {
        if (motion > 0) nudgeAnim.restart()
    }
    function openMenu() {
        if (!empty) appRoot.openSlotPanel(slot)
    }
    readonly property bool hovered: hover.hovered

    SequentialAnimation {
        id: riseAnim
        property var onDone
        NumberAnimation { target: slot; property: "lift"; to: 1; duration: 120 * slot.motion; easing.type: Easing.InCubic }
        ScriptAction { script: if (riseAnim.onDone) riseAnim.onDone() }
    }
    SequentialAnimation {
        id: nudgeAnim
        NumberAnimation { target: slot; property: "nudgeX"; to: -3; duration: 40 * slot.motion }
        NumberAnimation { target: slot; property: "nudgeX"; to: 3; duration: 60 * slot.motion }
        NumberAnimation { target: slot; property: "nudgeX"; to: 0; duration: 40 * slot.motion }
    }

    readonly property real mouthX: Math.round((width - 76) / 2)

    // The mouth: a slit cut into the shell, flush with it: a dark recess with a soft shadow at its
    // top and the shell's own lit edge below; it widens a little as a cartridge goes in. (No
    // raised flaps or seam: they stood out over the glass.)
    // On glass it stays the same thin, see-through slit with a cartridge in it (opening up, it
    // turned into a black bar that cut the glass and its rim).
    Rectangle {
        readonly property real h: 5 + (slot.glassy ? 0 : 3 * slot.open_)
        x: slot.mouthX
        y: slot.mouthY + (8 - h) / 2
        width: 76
        height: h
        radius: h / 2
        color: slot.glassy ? Qt.alpha(slot.g.mouth, 0.42) : Qt.alpha("#0a0a0c", 0.7 + 0.3 * slot.open_)
        Rectangle {  // the inner shadow at its top
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, slot.glassy ? 0.35 : 0.6) }
                GradientStop { position: 0.7; color: "transparent" }
            }
        }
    }

    // The cartridge, cut off at the slot line.
    Item {
        id: cartClip
        x: Math.round((slot.width - slot.cartW) / 2) - 30
        y: -300
        width: slot.cartW + 60
        height: 300 + slot.slotLine
        clip: true
        Cartridge {
            id: cart
            visible: slot.seated && !slot.empty
            x: 30 + slot.nudgeX
            y: 300 + slot.slotLine - slot.shown - slot.lift * (slot.cartH - slot.shown)
            // A full-size cartridge shrunk (like the design), so its art and lettering keep their
            // proportions; drawn at 64 px wide, generated art and text came out oversized.
            readonly property real fullW: 187
            width: fullW
            scale: slot.cartW / fullW
            transformOrigin: Item.TopLeft
            layer.enabled: visible
            layer.mipmap: true      // shrinking ×0.34 stays smooth
            layer.smooth: true
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
                anchors.margins: -3 / cart.scale
                radius: Backend.theme.geo.radius * cart.u + 3 / cart.scale
                color: "transparent"
                border.width: 2 / cart.scale
                border.color: Ui.focusColor
            }
        }
    }

    // The front lip over the cartridge's lower edge: a lit line, then shade (on glass only the
    // lit edge, fading out at its ends like the rim's light).
    Rectangle {
        visible: !slot.empty && slot.seated && slot.glassy
        x: slot.mouthX
        y: slot.slotLine - 1
        width: 76
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(slot.g.edge, 0) }
            GradientStop { position: 0.2; color: slot.g.edge }
            GradientStop { position: 0.8; color: slot.g.edge }
            GradientStop { position: 1.0; color: Qt.alpha(slot.g.edge, 0) }
        }
    }
    Rectangle {
        visible: !slot.empty && slot.seated && !slot.glassy
        x: Math.round((slot.width - 70) / 2)
        y: slot.slotLine - 1
        width: 70
        height: 3
        radius: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: slot.glassy ? slot.g.edge : slot.pal.dockHi }
            GradientStop { position: 0.34; color: slot.glassy ? slot.g.edge : slot.pal.dockHi }
            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, slot.glassy ? 0.2 : 0.28) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, slot.glassy ? 0.2 : 0.28) }
        }
    }

    Item {  // what takes the pointer: the cartridge above the slot
        visible: !slot.empty && slot.seated
        x: Math.round((slot.width - slot.cartW) / 2)
        y: slot.slotLine - slot.shown
        width: slot.cartW
        height: slot.shown
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        // Exclusive grabs: a tap on a docked cartridge must never also reach the cards behind it.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            enabled: !slot.appRoot.modalOpen || slot.appRoot.slotPanelFor(slot)
            // A tap selects the cartridge (the dock's keys act on it); tapping the selected one
            // opens its panel (art, name, play time…).
            onTapped: {
                if (slot.appRoot.slotPanelFor(slot)) slot.appRoot.closeSlotPanel()
                else if (slot.selected || !slot.several) slot.openMenu()
                else slot.dockItem.select(slot.gameId)
            }
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
    Keys.onSpacePressed: dockItem.select(gameId)
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            openMenu()
            event.accepted = true
        }
    }
    onActiveFocusChanged: if (activeFocus && !empty) dockItem.select(gameId)
}
