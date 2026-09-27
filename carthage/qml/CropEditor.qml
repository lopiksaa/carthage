// "Reposition Art…": drag the image inside the cartridge's art window, scroll to zoom.
// The whole original shows dimmed around the frame, so you can see what's cut off.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: ed

    property string gameId
    property string gameTitle
    property real aspect: 512 / 454
    property real cx: 0.5
    property real cy: 0.5
    property real zoom: 1

    function openFor(gid, title) {
        const info = Backend.artPicker.cropInfo(gid)
        gameId = gid
        gameTitle = title
        if (!info.url) {
            // Nothing to reposition yet (placeholder art).
            Window.window.showPassiveNotification(title + " has no art to reposition yet.", "short")
            return
        }
        aspect = info.aspect
        cx = info.cx !== undefined ? info.cx : 0.5
        cy = info.cy !== undefined ? info.cy : 0.5
        zoom = info.zoom !== undefined ? info.zoom : 1
        img.source = info.url
        open()
    }

    maxWidth: 620
    closePolicy: QQC2.Popup.CloseOnEscape

    contentItem: Column {
        spacing: Ui.gapM

        Column {
            width: parent.width
            Text {
                text: "Reposition Art"
                color: ed.pal.panelText
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
            }
            Text {
                width: parent.width
                text: ed.gameTitle + " · drag to move, scroll to zoom"
                color: ed.pal.panelTextDim
                font.family: "Nunito"
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
        }

        // The stage: the frame in the middle, the rest of the image dimmed around it.
        Rectangle {
            id: stage
            width: parent.width
            height: 380
            radius: Ui.radiusMedium
            color: "#0c0c0e"
            clip: true

            readonly property real frameW: Math.min(width * 0.62, height * 0.8 * ed.aspect)
            readonly property real frameH: frameW / ed.aspect
            readonly property real frameX: (width - frameW) / 2
            readonly property real frameY: (height - frameH) / 2
            // Image scale: at zoom 1, the largest aspect-shaped area of the image fills the frame.
            readonly property real iw: img.implicitWidth
            readonly property real ih: img.implicitHeight
            readonly property real s: iw > 0 ? stage.frameW / Math.min(iw, ih * ed.aspect) * ed.zoom : 1
            readonly property real imgX: frameX + frameW / 2 - ed.cx * iw * s
            readonly property real imgY: frameY + frameH / 2 - ed.cy * ih * s

            function clampCenter() {
                if (iw <= 0) return
                const halfW = frameW / 2 / s / iw, halfH = frameH / 2 / s / ih
                ed.cx = Math.min(Math.max(ed.cx, halfW), 1 - halfW)
                ed.cy = Math.min(Math.max(ed.cy, halfH), 1 - halfH)
            }

            Image {
                id: img
                x: stage.imgX
                y: stage.imgY
                width: stage.iw * stage.s
                height: stage.ih * stage.s
                opacity: 0.35
                smooth: true
                cache: false
                onStatusChanged: if (status === Image.Ready) stage.clampCenter()
            }
            // The part inside the frame, at full brightness.
            Item {
                x: stage.frameX
                y: stage.frameY
                width: stage.frameW
                height: stage.frameH
                clip: true
                Image {
                    x: stage.imgX - stage.frameX
                    y: stage.imgY - stage.frameY
                    width: img.width
                    height: img.height
                    source: img.source
                    smooth: true
                    cache: false
                }
            }
            Rectangle {
                x: stage.frameX - 2
                y: stage.frameY - 2
                width: stage.frameW + 4
                height: stage.frameH + 4
                color: "transparent"
                border.width: 2
                border.color: "#ffffff"
                radius: 3
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point last
                onPressed: (m) => last = Qt.point(m.x, m.y)
                onPositionChanged: (m) => {
                    ed.cx -= (m.x - last.x) / (stage.iw * stage.s)
                    ed.cy -= (m.y - last.y) / (stage.ih * stage.s)
                    last = Qt.point(m.x, m.y)
                    stage.clampCenter()
                }
                onWheel: (w) => {
                    ed.zoom = Math.min(4, Math.max(1, ed.zoom * (w.angleDelta.y > 0 ? 1.08 : 1 / 1.08)))
                    stage.clampCenter()
                }
            }
        }

        Row {
            width: parent.width
            spacing: Ui.gapM
            CIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "zoom-out-symbolic"
                isMask: true
                color: ed.pal.panelTextDim
            }
            QQC2.Slider {
                id: zoomSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 56
                from: 1
                to: 4
                value: ed.zoom
                onMoved: {
                    ed.zoom = value
                    stage.clampCenter()
                }
                Accessible.name: "Zoom"
            }
            CIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "zoom-in-symbolic"
                isMask: true
                color: ed.pal.panelTextDim
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            CButton {
                text: "Reset"
                onClicked: {
                    ed.cx = 0.5
                    ed.cy = 0.5
                    ed.zoom = 1
                }
            }
            CButton {
                text: "Cancel"
                onClicked: ed.close()
            }
            CButton {
                kind: "primary"
                text: "Save"
                onClicked: {
                    Backend.artPicker.setCrop(ed.gameId, ed.cx, ed.cy, ed.zoom)
                    ed.close()
                }
            }
        }
    }
}
