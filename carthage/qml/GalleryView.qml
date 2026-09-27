// Gallery mode for a game view (the library's closer look and store pages): a one-line bar
// (back to the details, the name, a short line, the main button) over the game's trailers
// and screenshots at full size. Scrolling up past the first one, the Details button, or
// choosing the peeking cartridge returns to the details, where they left off.
import QtQuick
import QtQuick.Controls as QQC2

Item {
    id: gv

    property var info: ({})
    property Item appRoot
    property string title
    property string subtitle
    property string actionText
    property string actionIcon
    property bool actionEnabled: true
    // For GalleryMorph: what its stand-ins turn into, hidden while they're under way.
    readonly property Item firstShot: gallery.firstShot
    readonly property Item actionItem: actionButton
    property bool morphing: false
    signal action()
    signal back()

    function toTop() { flick.contentY = 0 }

    Accessible.role: Accessible.Pane
    Accessible.name: title + ", screenshots"
    Keys.onEscapePressed: gv.back()

    // The bar: back, name and a short line, the main button.
    Item {
        id: bar
        width: parent.width
        height: Ui.controlHeight
        CButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            kind: "scrim"
            text: "Details"
            icon.name: "go-up-symbolic"
            onClicked: gv.back()
        }
        Column {
            anchors.left: backButton.right
            anchors.leftMargin: Ui.gapL
            anchors.right: actionButton.left
            anchors.rightMargin: Ui.gapL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                width: parent.width
                text: gv.title
                color: Ui.onScrim
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: gv.subtitle
                color: Ui.onScrimDim
                font.family: "Nunito"
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
                elide: Text.ElideRight
            }
        }
        CButton {
            id: actionButton
            anchors.right: parent.right
            anchors.rightMargin: Ui.gapL
            anchors.verticalCenter: parent.verticalCenter
            kind: "primary"
            opacity: gv.morphing ? 0 : 1
            text: gv.actionText
            icon.name: gv.actionIcon
            enabled: gv.actionEnabled
            onClicked: gv.action()
        }
    }

    Flickable {
        id: flick
        anchors.top: bar.bottom
        anchors.topMargin: Ui.gapL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: gallery.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar { onDark: true }
        WheelAccel {
            flickable: flick
            step: 140
            onPastStart: gv.back()
        }
        MediaGallery {
            id: gallery
            width: flick.width - Ui.gapL
            info: gv.info
            appRoot: gv.appRoot
            showTitle: false
            hideFirst: gv.morphing
        }
    }
}
