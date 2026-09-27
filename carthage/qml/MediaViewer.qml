// Full-window viewer for a store game's trailers and screenshots.
import QtQuick
import QtQuick.Controls as QQC2
import QtMultimedia

QQC2.Popup {
    id: viewer

    // [{kind: "image"|"video", thumb, url}]
    property var media: []
    property int index: 0
    readonly property var cur: media.length ? media[index] : ({})

    function openAt(list, i) {
        media = list
        index = Math.max(0, Math.min(i, list.length - 1))
        open()
        forceActiveFocus()
    }
    function go(d) {
        if (media.length) index = (index + d + media.length) % media.length
    }

    parent: QQC2.Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 800
    height: parent ? parent.height : 600
    padding: 0
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape
    onClosed: player.stop()
    QQC2.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.9) }

    background: Item {}

    contentItem: Item {
        focus: true
        Keys.onLeftPressed: viewer.go(-1)
        Keys.onRightPressed: viewer.go(1)
        Keys.onSpacePressed: if (viewer.cur.kind === "video") player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()

        MouseArea {
            anchors.fill: parent
            onClicked: viewer.close()
        }

        Item {
            id: stageArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: strip.top
            anchors.margins: 40
            anchors.bottomMargin: 20

            Image {
                id: bigImage
                visible: viewer.cur.kind !== "video"
                anchors.fill: parent
                source: viewer.cur.kind === "image" ? viewer.cur.url : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                QQC2.BusyIndicator { anchors.centerIn: parent; running: parent.status === Image.Loading }
            }
            VideoOutput {
                id: video
                visible: viewer.cur.kind === "video"
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
            MediaPlayer {
                id: player
                videoOutput: video
                audioOutput: AudioOutput { volume: 0.6 }
                source: viewer.opened && viewer.cur.kind === "video" ? viewer.cur.url : ""
                onSourceChanged: if (source != "") play()
            }
            MouseArea {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * 16 / 9)
                height: Math.min(parent.height, parent.width * 9 / 16)
                onClicked: if (viewer.cur.kind === "video")
                               player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
            }
        }

        Repeater {
            model: [-1, 1]
            delegate: Rectangle {
                required property var modelData
                visible: viewer.media.length > 1
                anchors.verticalCenter: stageArea.verticalCenter
                x: modelData < 0 ? 14 : parent.width - width - 14
                width: 48
                height: 48
                radius: 24
                color: arrowHover.hovered ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                CIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: parent.modelData < 0 ? "go-previous-symbolic" : "go-next-symbolic"
                    isMask: true
                    color: "#ffffff"
                }
                HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: viewer.go(parent.modelData) }
            }
        }

        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 16
            text: (viewer.index + 1) + " / " + viewer.media.length
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: "Nunito"
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
        }
        CButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            kind: "ghost"
            tint: "#ffffff"
            icon.name: "window-close-symbolic"
            Accessible.name: "Close"
            onClicked: viewer.close()
        }

        ListView {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            height: 76
            orientation: ListView.Horizontal
            spacing: Ui.gapM
            leftMargin: Math.max(20, (width - contentWidth) / 2)
            model: viewer.media
            currentIndex: viewer.index
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: 120
                height: 68
                radius: Ui.radiusSmall
                color: "#111"
                clip: true
                border.width: index === viewer.index ? 3 : 0
                border.color: "#ffffff"
                opacity: index === viewer.index ? 1 : 0.6
                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    source: modelData.thumb
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                CIcon {
                    visible: modelData.kind === "video"
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: "media-playback-start-symbolic"
                    isMask: true
                    color: "#ffffff"
                }
                TapHandler { onTapped: viewer.index = index }
            }
        }
    }

}
