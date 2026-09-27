// A category as a chunky plastic tile: its own color, the name in big type, a soft
// highlight on top. Lifts a little on hover, sinks when pressed.
import QtQuick
import Carthage

Item {
    id: tile

    property string name
    property int tag: 0
    property bool compact: false
    readonly property string art: Backend.store.categoryArt[String(tag)] || ""
    signal chosen()

    // A stable color per category, derived from its name.
    readonly property color plastic: {
        let h = 0
        for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 360
        return Qt.hsla(h / 360, 0.52, 0.42, 1)
    }

    implicitWidth: compact ? 170 : 220
    implicitHeight: compact ? 96 : 120
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: name
    Keys.onReturnPressed: chosen()
    Keys.onSpacePressed: chosen()

    Rectangle { // contact shadow
        anchors.fill: body
        anchors.topMargin: 6
        anchors.leftMargin: 3
        anchors.rightMargin: -3
        anchors.bottomMargin: -6 - 4 * lift
        radius: Ui.radiusLarge
        color: Qt.rgba(0, 0, 0, 0.35)
    }
    Rectangle {
        id: body
        width: parent.width
        height: parent.height
        y: -4 * tile.lift + (tap.pressed ? 2 : 0)
        radius: Ui.radiusLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(tile.plastic, 1.25) }
            GradientStop { position: 1.0; color: Qt.darker(tile.plastic, 1.15) }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        // The category's top game (once opened), washed in the tile's color so the name
        // always reads. Decoded at the tile's size (a 460 px header squeezed into 170 px
        // shimmered) and clipped with soft, antialiased corners.
        Item {
            anchors.fill: parent
            anchors.margins: 1
            visible: art.status === Image.Ready
            layer.enabled: visible
            layer.smooth: true
            layer.effect: RoundedMask { radius: Ui.radiusLarge - 1 }
            Image {
                id: art
                anchors.fill: parent
                source: tile.art
                sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(tile.plastic, 0.15) }
                    GradientStop { position: 0.55; color: Qt.alpha(tile.plastic, 0.55) }
                    GradientStop { position: 1.0; color: Qt.alpha(Qt.darker(tile.plastic, 1.3), 0.95) }
                }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Ui.gapL
            width: parent.width - 2 * Ui.gapL
            text: tile.name
            color: "#ffffff"
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: tile.compact ? Ui.textLead + 2 : Ui.textTitle + 2
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
        Rectangle {
            visible: tile.activeFocus
            anchors.fill: parent
            anchors.margins: -4
            radius: Ui.radiusLarge + 4
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
    }

    property real lift: hover.hovered ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: tile.chosen() }
}
