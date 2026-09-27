// The store's big banner (Steam's spotlight and popular new releases): a wide carousel at
// the top of the store, set in a plastic bezel like a little screen. Turns every 6 s, pauses while hovered; arrows and dots to browse, click
// to open the game.
import QtQuick

import Carthage
Item {
    id: banner

    property var items: []
    property Item appRoot
    property int index: 0
    readonly property var pal: Backend.theme.p
    readonly property var cur: items.length ? items[Math.min(index, items.length - 1)] : ({})
    signal chosen(var item)

    implicitHeight: Math.round(width * 0.36)

    function go(i) {
        if (!items.length) return
        index = (i + items.length) % items.length
        fade.restart()
    }

    Timer {
        running: banner.visible && banner.items.length > 1 && !hh.hovered
        interval: 6000
        repeat: true
        onTriggered: banner.go(banner.index + 1)
    }
    NumberAnimation { id: fade; target: shot; property: "opacity"; from: 0.25; to: 1; duration: 420; easing.type: Easing.OutCubic }

    // Bezel: the hardware's plastic around a dark screen.
    Rectangle {
        anchors.fill: parent
        radius: Ui.radiusLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: banner.pal.dockTop }
            GradientStop { position: 1.0; color: banner.pal.dockBottom }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        id: screen
        anchors.fill: parent
        anchors.margins: 10
        radius: Ui.radiusMedium
        color: "#050506"
        clip: true
        // Rounded clip for the art (clip alone only cuts the square outline).
        layer.enabled: true
        layer.effect: RoundedMask { radius: screen.radius }

        Image {
            id: shot
            anchors.fill: parent
            source: banner.cur.banner || banner.cur.header || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
        }
        // Readable text over any art: a dark gradient from the bottom-left.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.78) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.1) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Column {
            id: caption
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 26
            width: parent.width * 0.5
            spacing: Ui.gapS
            Text {
                text: "SPOTLIGHT"
                color: Qt.rgba(1, 1, 1, 0.75)
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textCaption
                font.letterSpacing: 2
            }
            Text {
                width: parent.width
                text: banner.cur.name || ""
                color: "#ffffff"
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Math.max(20, banner.height * 0.1)
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Row {
                spacing: Ui.gapM
                Rectangle {
                    visible: (banner.cur.discount || 0) > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: dt.implicitWidth + 16
                    height: 30
                    radius: Ui.radiusSmall
                    color: "#3f8f12"
                    antialiasing: true
                    Text {
                        id: dt
                        anchors.centerIn: parent
                        text: "-" + (banner.cur.discount || 0) + "%"
                        color: "#ffffff"
                        font.family: "Nunito"
                        font.weight: Font.Black
                        font.pixelSize: Ui.textLead
                    }
                }
                Text {
                    visible: (banner.cur.original || "") !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: banner.cur.original || ""
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: "Nunito"
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textLead
                    font.strikeout: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: banner.cur.owned ? "In your library" : (banner.cur.price || "")
                    color: "#ffffff"
                    font.family: "Nunito"
                    font.weight: Font.Black
                    font.pixelSize: Ui.textTitle
                }
            }
        }

        // Dots.
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18
            spacing: Ui.gapS
            Repeater {
                model: banner.items.length
                delegate: Rectangle {
                    required property int index
                    width: index === banner.index ? 22 : 8
                    height: 8
                    radius: 4
                    color: index === banner.index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
                    Behavior on width { NumberAnimation { duration: 180 } }
                    TapHandler { onTapped: banner.go(index) }
                }
            }
        }
    }

    HoverHandler {
        id: hh
        cursorShape: Qt.PointingHandCursor
        enabled: !banner.appRoot.modalOpen
    }
    TapHandler {
        enabled: !banner.appRoot.modalOpen
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (ev) => {
            // Side thirds turn the carousel; the middle opens the game.
            const x = ev.position.x
            if (x < banner.width * 0.12) banner.go(banner.index - 1)
            else if (x > banner.width * 0.88) banner.go(banner.index + 1)
            else banner.chosen(banner.cur)
        }
    }

    // Arrows, shown on hover.
    Repeater {
        model: [-1, 1]
        delegate: Rectangle {
            required property var modelData
            visible: hh.hovered && banner.items.length > 1
            // Centered in the picture above the caption (on a small banner, the middle is
            // where the caption is).
            y: Math.max(22, Math.round((screen.y + caption.y - height) / 2))
            x: modelData < 0 ? 22 : banner.width - width - 22
            width: 40
            height: 40
            radius: 20
            color: Qt.rgba(0, 0, 0, 0.55)
            CIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: parent.modelData < 0 ? "go-previous-symbolic" : "go-next-symbolic"
                isMask: true
                color: "#ffffff"
            }
        }
    }
}
