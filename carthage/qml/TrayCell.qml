// One recess in the tray with its cartridge: hover tilt, press, drag, context menu.
import QtQuick
import Carthage

Item {
    id: cell

    // Arriving (after setup, App.qml introCards): the cartridges in view pop in one by one, in
    // reading order; the rest are simply there.
    property real intro: 1
    opacity: intro
    NumberAnimation { id: introAnim; target: cell; property: "intro"; from: 0; to: 1; duration: 360 * Backend.motion; easing.type: Easing.OutBack }
    Timer { id: introWait; onTriggered: introAnim.restart() }
    Connections {
        target: cell.appRoot
        function onIntroCards() {
            const g = cell.GridView.view
            // (any card on screen at all: the ones partly hidden or under the dock too)
            if (!g || Backend.motion <= 0 || cell.y + cell.height <= g.contentY || cell.y >= g.contentY + g.height) return
            const row = Math.floor((cell.y - g.contentY) / g.cellHeight)
            const col = Math.round(cell.x / g.cellWidth)
            cell.intro = 0
            introWait.interval = 450 + (Math.max(0, row) * g.columns + col) * 70
            introWait.restart()
        }
    }

    required property int index
    required property string gameId
    required property string title
    required property string source
    required property string sourceName
    required property string sourceIcon
    required property string code
    required property string extId
    required property bool installed
    required property bool noSlot
    required property int lastPlayed
    required property int playtime
    required property string developer
    required property string publisher
    required property int released

    property Item appRoot

    readonly property var pal: Backend.theme.p
    readonly property string edition: Backend.theme.edition
    readonly property real motion: appRoot ? appRoot.motion : 1
    readonly property bool out: appRoot ? appRoot.hiddenCards[gameId] === true : false
    readonly property real cardW: Backend.settings.cardWidth
    readonly property real cardH: cardW * Backend.theme.ratio
    readonly property real pad: cardW * 0.035 // must match render.RECESS_PAD
    readonly property real pocketX: Math.round((width - pocket.width) / 2)
    readonly property real pocketY: Ui.spacingLarge * 2
    readonly property real cardX: pocketX + pad
    readonly property real cardY: pocketY + pad

    readonly property bool keyFocus: GridView.isCurrentItem && GridView.view.activeFocus && GridView.view.keyboardNav
    readonly property bool hovered: hover.hovered && !out
    readonly property point pointer: hover.point.position
    readonly property bool tilting: hovered && Backend.settings.tiltEnabled && motion > 0
    readonly property bool spotlit: appRoot ? appRoot.diceSpot === gameId : false

    property real lift: (hovered || keyFocus || spotlit) && !out && motion > 0 ? 1 : 0
    Behavior on lift {
        NumberAnimation { duration: 100 * cell.motion; easing.type: Easing.OutCubic }
    }
    property real pressScale: 1
    property real nudgeX: 0

    readonly property real tiltMax: 10
    property real tiltX: tilting ? -(pointer.y / cardH - 0.5) * 2 * tiltMax : 0
    property real tiltY: tilting ? (pointer.x / cardW - 0.5) * 2 * tiltMax : 0
    Behavior on tiltX {
        SpringAnimation { spring: 5; damping: 0.55; epsilon: 0.05 }
    }
    Behavior on tiltY {
        SpringAnimation { spring: 5; damping: 0.55; epsilon: 0.05 }
    }

    property alias card: card

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight
    z: lift > 0 ? 2 : 0

    Accessible.role: Accessible.Button
    Accessible.name: title + ", " + (installed ? "installed" : "not installed") + ", "
                     + sourceName.charAt(0) + sourceName.slice(1).toLowerCase()
    Accessible.onPressAction: appRoot.choose(cell)

    function press() {
        if (motion > 0) pressAnim.restart()
    }
    function nudge() {
        if (motion > 0) nudgeAnim.restart()
    }
    // Destroyed mid-drag (the list rebuilt): the carried cartridge must still go home.
    Component.onDestruction: if (pickUp.active) appRoot.cancelCardDrag()

    function openMenu(atPointer) {
        GridView.view.openCardMenu(cell, atPointer)
    }

    SequentialAnimation {
        id: pressAnim
        NumberAnimation { target: cell; property: "pressScale"; to: 0.97; duration: 80 * cell.motion; easing.type: Easing.OutQuad }
        NumberAnimation { target: cell; property: "pressScale"; to: 1; duration: 120 * cell.motion; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        id: nudgeAnim
        NumberAnimation { target: cell; property: "nudgeX"; to: -4; duration: 40 * cell.motion }
        NumberAnimation { target: cell; property: "nudgeX"; to: 4; duration: 60 * cell.motion }
        NumberAnimation { target: cell; property: "nudgeX"; to: 0; duration: 40 * cell.motion }
    }

    Item {
        id: pocket
        x: cell.pocketX
        y: cell.pocketY
        width: cell.cardW + 2 * cell.pad
        height: cell.cardH + 2 * cell.pad

        Image {
            visible: !Backend.theme.glassy
            anchors.fill: parent
            source: visible ? "image://gc/recess/" + cell.edition : ""
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
        }
        Image {  // glass: a raised glass card; the image reaches past the well for its shadow
            readonly property real m: 0.22 * parent.width  // render.GLASS_WELL_MARGIN
            visible: Backend.theme.glassy
            x: -m
            y: -m
            width: parent.width + 2 * m
            height: parent.height + 2 * m
            source: visible ? "image://gc/glasswell/" + Backend.theme.edition + "/" + (Backend.theme.dark ? "dark" : "light") : ""
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
        }

        Item {
            visible: cell.out
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: cell.cardW * 0.1
            anchors.bottomMargin: cell.cardW * 0.12
            height: engraved.implicitHeight

            Text {
                x: 1
                y: 1
                width: parent.width
                text: engraved.text
                font: engraved.font
                fontSizeMode: engraved.fontSizeMode
                minimumPixelSize: engraved.minimumPixelSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: cell.pal.engraveHi
                visible: !Backend.theme.glassy
            }
            Text {
                id: engraved
                width: parent.width
                text: cell.title.toUpperCase()
                font.family: Ui.fontTitles
                font.weight: Font.ExtraBold
                font.pixelSize: Math.max(8, cell.cardW * 0.085)
                // Long names shrink to fit rather than being cut (down to 70%).
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.max(7, cell.cardW * 0.06)
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Backend.theme.glassy ? Backend.theme.glass.text2 : cell.pal.engrave
            }
        }
    }

    Image {
        visible: !cell.out
        readonly property real sp: cell.cardW * 0.16 // must match render.SHADOW_PAD
        x: cell.cardX - sp + cell.cardW * (0.018 + 0.04 * cell.lift) + cell.nudgeX
        y: cell.cardY - sp + cell.cardW * (0.03 + 0.07 * cell.lift)
        width: cell.cardW + 2 * sp
        height: cell.cardH + 2 * sp
        scale: 1 + 0.03 * cell.lift
        opacity: cell.pal.shadowStrength * (0.75 + 0.25 * cell.lift)
        source: "image://gc/shadow/" + cell.edition
        sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2)) // blurry anyway
        asynchronous: true
    }

    // Snaps on and fades off, so it reads as a light hopping from card to card.
    Item {
        id: spot
        visible: opacity > 0
        opacity: cell.spotlit && !cell.out ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: (spot.opacity < 0.5 ? 40 : 280) * Backend.motion; easing.type: Easing.OutQuad } }
        Repeater {
            model: [0.5, 0.25, 0.12]
            Rectangle {
                required property real modelData
                required property int index
                readonly property real m: 3 + index * 4
                x: cell.cardX - m + cell.nudgeX
                y: cell.cardY - m - cell.cardW * 0.035 * cell.lift
                width: cell.cardW + 2 * m
                height: cell.cardH + 2 * m
                radius: Backend.theme.geo.radius * card.u + m
                color: Backend.theme.accent.accent
                opacity: modelData
            }
        }
    }

    Cartridge {
        id: card
        visible: !cell.out
        x: cell.cardX + cell.nudgeX
        y: cell.cardY
        width: cell.cardW
        gameId: cell.gameId
        title: cell.title
        source: cell.source
        // (until the tilt has settled too: it springs back after the lift is gone, and text
        // drawn directly under a slight tilt slants letter by letter)
        smoothTransform: cell.lift > 0.001 || cell.pressScale !== 1 || Math.abs(cell.tiltX) > 0.02 || Math.abs(cell.tiltY) > 0.02
        sourceName: cell.sourceName
        sourceIcon: cell.sourceIcon
        code: cell.code
        extId: cell.extId
        installed: cell.installed
        noSlot: cell.noSlot
        glare: cell.tilting
        glarePoint: cell.pointer
        glareStrength: cell.lift

        transform: [
            Translate { y: -cell.cardW * 0.035 * cell.lift },
            Rotation {
                origin.x: cell.cardW / 2
                origin.y: cell.cardH / 2
                axis { x: 1; y: 0; z: 0 }
                angle: cell.tiltX
                distanceToPlane: cell.cardW * 5.5
            },
            Rotation {
                origin.x: cell.cardW / 2
                origin.y: cell.cardH / 2
                axis { x: 0; y: 1; z: 0 }
                angle: cell.tiltY
                distanceToPlane: cell.cardW * 5.5
            },
            Scale {
                origin.x: cell.cardW / 2
                origin.y: cell.cardH / 2
                xScale: (1 + 0.05 * cell.lift) * cell.pressScale
                yScale: xScale
            }
        ]

        Rectangle {
            visible: cell.keyFocus
            anchors.fill: parent
            anchors.margins: -5
            radius: Backend.theme.geo.radius * card.u + 5
            color: "transparent"
            border.width: 3
            border.color: Ui.focusColor
        }
    }

    // Input on an untransformed area, so the tilt can't make the pointer "fall off".
    Item {
        x: cell.cardX
        y: cell.cardY
        width: cell.cardW
        height: cell.cardH

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            enabled: !cell.appRoot.modalOpen && !Ui.bodyBlocked  // (a handler isn't switched off with its item)
            onHoveredChanged: if (hovered && !cell.out) cell.appRoot.sound("hover")
        }
        DragHandler {
            id: pickUp
            target: null
            // Stays on while carrying the card (picking it up marks it "out").
            enabled: !cell.appRoot.modalOpen && (!cell.out || active)
            dragThreshold: 8
            // The tray can't take the pointer away to scroll (that would cancel the drag).
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onActiveChanged: {
                if (active) {
                    const pp = centroid.pressPosition
                    cell.appRoot.startCardDrag(cell, centroid.scenePressPosition,
                                               Qt.point(pp.x / cell.cardW, pp.y / cell.cardH))
                } else {
                    cell.appRoot.endCardDrag(centroid.scenePosition)
                }
            }
            onCentroidChanged: if (active) cell.appRoot.moveCardDrag(centroid.scenePosition)
            onCanceled: cell.appRoot.cancelCardDrag()
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: !cell.appRoot.modalOpen
            onTapped: {
                cell.GridView.view.currentIndex = cell.index
                cell.GridView.view.keyboardNav = false
                cell.appRoot.choose(cell)
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: !cell.appRoot.modalOpen
            onTapped: {
                cell.GridView.view.currentIndex = cell.index
                if (cell.out) cell.appRoot.openDockMenu(cell.gameId)
                else cell.openMenu(true)
            }
        }
    }

    Text {
        visible: Backend.settings.showTitles
        anchors.top: pocket.bottom
        anchors.topMargin: Ui.spacingSmall * 2
        anchors.horizontalCenter: pocket.horizontalCenter
        width: pocket.width + Ui.spacingLarge
        text: cell.title
        // The name opens the game too (people aim for it).
        TapHandler { onTapped: if (!cell.out) cell.appRoot.choose(cell) }
        HoverHandler { cursorShape: Qt.PointingHandCursor; enabled: !Ui.bodyBlocked }
        color: cell.installed ? cell.pal.trayText : cell.pal.trayTextDim
        font.family: Ui.fontText  // the chosen text font (was the app default, Nunito)
        font.pixelSize: Ui.textBody
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
}
