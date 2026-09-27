// One store game as a cartridge on a shelf: capsule art, the price on the label strip, a
// discount sticker, and an "In library" tag for games you already own.
import QtQuick

import Carthage
Item {
    id: card

    property var item: ({})
    property real cardW: 150
    property Item appRoot
    signal chosen(var item, Item cart)

    readonly property var pal: Backend.theme.p
    // Which store's cartridge this is (Steam unless the game comes from another store).
    readonly property string store: item.store || "steam"
    readonly property string storeName: Backend.store.storeNames[store] || "Store"
    readonly property bool hovered: hh.hovered

    // Each cartridge sits in a molded pocket, like in the library's tray.
    readonly property real pad: cardW * 0.035 // must match render.RECESS_PAD
    readonly property real cardH: cardW * Backend.theme.ratio

    width: cardW + 2 * pad
    height: cardH + 2 * pad + (item.players !== undefined ? 76 : 58)

    Image {
        width: card.cardW + 2 * card.pad
        height: card.cardH + 2 * card.pad
        source: "image://gc/recess/" + Backend.theme.edition
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        asynchronous: true
    }

    // Resting shadow, lifted a little on hover.
    Image {
        readonly property real sp: card.cardW * 0.16
        x: card.pad - sp + card.cardW * (0.02 + 0.03 * lift.value)
        y: card.pad - sp + card.cardW * (0.03 + 0.06 * lift.value)
        width: card.cardW + 2 * sp
        height: card.cardW * Backend.theme.ratio + 2 * sp
        opacity: card.pal.shadowStrength * (0.75 + 0.25 * lift.value)
        source: "image://gc/shadow/" + Backend.theme.cardEdition
        sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
    }

    Cartridge {
        id: cart
        x: card.pad
        y: card.pad
        width: card.cardW
        source: card.store
        sourceName: card.storeName.toUpperCase()
        sourceIcon: card.store
        installed: true
        artUrl: card.item.capsule || ""
        artFallback: card.item.header || ""
        labelOverride: card.item.price ? card.item.price.toUpperCase() : card.storeName.toUpperCase()
        labelSize: 64
        smoothTransform: lift.value > 0.001
        transform: [
            Translate { y: -card.cardW * 0.035 * lift.value },
            Scale {
                origin.x: card.cardW / 2
                origin.y: cart.height / 2
                xScale: 1 + 0.05 * lift.value
                yScale: xScale
            }
        ]

        // Owned: a small tag instead of a price.
        Rectangle {
            visible: card.item.owned === true
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.28
            width: ownedText.implicitWidth + 16
            height: ownedText.implicitHeight + 8
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.72)
            Text {
                id: ownedText
                anchors.centerIn: parent
                text: "IN LIBRARY"
                color: "#ffffff"
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Math.max(8, card.cardW * 0.07)
                font.letterSpacing: 1
            }
        }
    }

    // Discount sticker, stuck on at an angle. Drawn outside the cartridge (not inside its
    // tilt texture) and antialiased, so it stays crisp.
    Item {
        visible: (card.item.discount || 0) > 0
        x: card.pad + card.cardW - width * 0.72
        y: card.pad - height * 0.3 - card.cardW * 0.035 * lift.value
        width: card.cardW * 0.42
        height: width * 0.5
        rotation: 10
        antialiasing: true
        z: 2
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            antialiasing: true
            color: "#3f8f12"
            border.width: 2
            border.color: "#dff7c8"
        }
        Text {
            anchors.centerIn: parent
            text: "-" + card.item.discount + "%"
            color: "#ffffff"
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Math.max(12, card.cardW * 0.12)
            renderType: Text.CurveRendering  // rotated with the sticker: no subpixel color fringes
        }
    }

    // Name under the cartridge, styled like the library's titles.
    Text {
        id: nameText
        anchors.top: cart.bottom
        anchors.topMargin: Ui.gapM + card.pad
        anchors.horizontalCenter: cart.horizontalCenter
        width: card.cardW + Ui.gapL
        horizontalAlignment: Text.AlignHCenter
        text: card.item.name || ""
        color: card.pal.trayText
        font.family: "Nunito"
        font.pixelSize: Ui.textBody
        lineHeight: 1.1
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    // Charts: players right now, under the name.
    Text {
        visible: card.item.players !== undefined
        anchors.top: nameText.bottom
        anchors.topMargin: 2
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: (card.item.players || "") + " playing now"
        color: card.pal.trayTextDim
        font.family: "Nunito"
        font.weight: Font.Bold
        font.pixelSize: Ui.textCaption
    }
    // Charts: the rank as a small plastic badge on the cartridge's top-left corner (the
    // discount sticker takes the top-right). Gold, silver and bronze for the top three.
    Rectangle {
        id: rankBadge
        visible: card.item.rank !== undefined
        readonly property int rank: card.item.rank || 0
        x: card.pad - width * 0.28
        y: card.pad - height * 0.3 - card.cardW * 0.035 * lift.value
        z: 2
        width: Math.max(height, rankText.implicitWidth + 16)
        height: Math.max(22, card.cardW * 0.19)
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: rankBadge.rank === 1 ? "#f3c94a" : rankBadge.rank === 2 ? "#d4d9df" : rankBadge.rank === 3 ? "#d99a5b" : "#3a3a40" }
            GradientStop { position: 1.0; color: rankBadge.rank === 1 ? "#c8981c" : rankBadge.rank === 2 ? "#9aa2ab" : rankBadge.rank === 3 ? "#a8652c" : "#1d1d22" }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        Text {
            id: rankText
            anchors.centerIn: parent
            text: "#" + rankBadge.rank
            color: rankBadge.rank >= 1 && rankBadge.rank <= 3 ? "#1d1a14" : "#ffffff"
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Math.max(11, card.cardW * 0.1)
            renderType: Text.QtRendering
        }
    }

    NumberAnimation { id: liftAnim; target: lift; property: "value"; duration: 110; easing.type: Easing.OutCubic }
    QtObject { id: lift; property real value: 0 }
    HoverHandler {
        id: hh
        cursorShape: Qt.PointingHandCursor
        enabled: !card.appRoot.modalOpen
        onHoveredChanged: {
            liftAnim.to = hovered ? 1 : 0
            liftAnim.restart()
            if (hovered) card.appRoot.sound("hover")
        }
    }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: !card.appRoot.modalOpen
        onTapped: card.chosen(card.item, cart)
    }
    Accessible.role: Accessible.Button
    Accessible.name: (item.name || "") + ", " + (item.owned ? "in your library" : (item.price || ""))
                     + (store !== "steam" ? ", " + storeName : "")
}
