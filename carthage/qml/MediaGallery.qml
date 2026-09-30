// A game's trailers and screenshots, full width, one under another. Fed with a store details
// object (store.py loadDetails).
import QtQuick
import Carthage

Column {
    id: gallery

    property var info: ({})
    property Item appRoot
    property bool showTitle: true
    property bool hideFirst: false
    readonly property Item firstShot: shots.count > 0 ? shots.itemAt(0) : null

    readonly property var media: {
        const out = []
        for (const m of (info.movies || [])) if (m.url) out.push({ kind: "video", thumb: m.thumb, url: m.url })
        const thumbs = info.screenshots || [], full = info.screenshotsFull || []
        for (let i = 0; i < thumbs.length; i++)
            out.push({ kind: "image", thumb: thumbs[i], url: full[i] || thumbs[i], big: full[i] || thumbs[i] })
        return out
    }
    readonly property bool hasVideo: media.length > 0 && media[0].kind === "video"

    visible: media.length > 0
    spacing: Ui.gapM
    Accessible.role: Accessible.List
    Accessible.name: "Trailers and screenshots"

    Text {
        visible: gallery.showTitle
        text: gallery.hasVideo ? "Trailers & Screenshots" : "Screenshots"
        color: Ui.onScrim
        font.family: Ui.fontText
        font.weight: Font.Black
        font.pixelSize: Ui.textLead
    }

    Repeater {
        id: shots
        model: gallery.media
        delegate: MediaTile {
            id: shot
            required property var modelData
            required property int index
            width: gallery.width
            height: Math.round(width * 9 / 16)
            media: modelData
            opacity: gallery.hideFirst && index === 0 ? 0 : 1
            zoomed: shotHover.hovered
            Accessible.role: Accessible.Button
            Accessible.name: (modelData.kind === "video" ? "Trailer " : "Screenshot ") + (index + 1)

            // Full-size images load one at a time: Steam's image server refuses too many at
            // once ("excessive load").
            sharp: false
            Timer { interval: 400 + shot.index * 350; running: !!shot.modelData.big; onTriggered: shot.sharp = true }
            HoverHandler { id: shotHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: gallery.appRoot.viewMedia(gallery.media, shot.index) }
        }
    }
}
