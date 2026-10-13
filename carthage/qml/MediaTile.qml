// A trailer or screenshot tile. The full-size image loads once `sharp` (MediaGallery staggers
// them).
//   MediaTile { media: { kind: "image", thumb: url, big: url } }
import QtQuick
import Carthage

Rectangle {
    id: tile

    property var media: null
    property bool sharp: true
    property real loadWidth: width  // the width the full image is decoded at
    property bool zoomed: false     // grows a hair (hover)

    radius: Ui.radiusMedium
    clip: true
    color: Qt.rgba(1, 1, 1, 0.06)
    layer.enabled: visible
    layer.effect: RoundedMask { radius: tile.radius }
    // At the size it's loaded for, not its current size: growing (GameView's zoom), the layer
    // was made again on every frame; now it's only drawn larger or smaller.
    layer.textureSize: Qt.size(Math.ceil(Math.max(width, loadWidth) * Screen.devicePixelRatio),
                               Math.ceil(Math.max(height, loadWidth * height / Math.max(1, width)) * Screen.devicePixelRatio))
    layer.smooth: true

    Image {
        anchors.fill: parent
        source: tile.media ? tile.media.thumb : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: full.status !== Image.Ready
    }
    Image {
        id: full
        anchors.fill: parent
        source: tile.sharp && tile.media && tile.media.big ? tile.media.big : ""
        sourceSize.width: Math.ceil(Math.max(1, tile.loadWidth) * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        scale: tile.zoomed ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 140 * Backend.motion; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        visible: !!tile.media && tile.media.kind === "video"
        anchors.centerIn: parent
        width: 60
        height: 60
        radius: 30
        color: Qt.rgba(0, 0, 0, 0.6)
        CIcon {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: "media-playback-start-symbolic"
            isMask: true
            color: Ui.onScrim
        }
    }
}
