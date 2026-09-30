// The hand-off from a game's details to its gallery, driven by the scroll position: the first
// screenshot grows into the gallery, the main button moves into the gallery bar. It never rests
// halfway: when scrolling stops mid-morph it settles forward or back. Stand-ins do the moving
// while the real items are hidden. Expects `gallery` to be a MediaGallery directly inside a
// Column at the top of `flick`.
import QtQuick
import Carthage

Item {
    id: m

    property Flickable flick
    property WheelAccel wheel    // the details' wheel scrolling (the morph settles through it)
    property Item gallery        // MediaGallery in the details column
    property Item view           // GalleryView
    property Item button         // the details' main button
    property bool active: true   // the page is open, in its wide layout
    property real motion: 1
    property bool galleryMode: false
    signal entered()

    // (Whether the game has any, not whether they show: the details hide in gallery mode.)
    readonly property Item shot: gallery && gallery.media && gallery.media.length ? gallery.firstShot : null
    readonly property bool usable: active && !!flick && !!shot && !!view

    readonly property real shotTop: shot ? gallery.y + shot.y : 0
    readonly property real startY: usable && shot ? Math.max(0, shotTop - Math.max(flick.height - shot.height, flick.height * 0.3)) : 0
    readonly property real endY: Math.max(startY + 1, shotTop)
    // The details must be able to scroll that far, however short they are.
    readonly property real neededContentHeight: usable ? endY + flick.height : 0

    readonly property real progress: galleryMode ? 1 : !usable ? 0
                                     : Math.max(0, Math.min(1, (flick.contentY - startY) / (endY - startY)))
    readonly property real level: progress * progress * (3 - 2 * progress)
    readonly property bool morphing: !galleryMode && progress > 0 && progress < 1
    readonly property real detailsOpacity: 1 - Math.max(0, Math.min(1, (level - 0.1) / 0.35))
    readonly property real galleryOpacity: Math.max(0, Math.min(1, (level - 0.55) / 0.45))

    function exit() {
        if (!galleryMode) return
        galleryMode = false
        glide(startY, 520)
    }
    function reset() {  // no animation: closing, or showing another game
        if (wheel) wheel.glide.stop()
        galleryMode = false
    }
    function glide(to, ms) {
        if (motion <= 0 || !wheel) flick.contentY = to
        else wheel.glideTo(to, ms * motion)
    }

    property int lastDir: 0
    Timer {
        id: idle
        interval: 160
        onTriggered: m.settle()
    }
    function settle() {
        if (!usable || galleryMode) return
        if (flick.moving || (wheel && wheel.gliding)) {
            idle.restart()  // still going
            return
        }
        const p = (flick.contentY - startY) / (endY - startY)
        if (p <= 0 || p >= 1) return
        const forward = (lastDir > 0 && p > 0.12) || p > 0.6
        glide(forward ? endY : startY, 140 + 380 * (forward ? 1 - p : p))
    }

    onUsableChanged: if (!usable) reset()

    property real lastY: 0
    Connections {
        target: m.flick
        function onContentYChanged() {
            const f = m.flick
            const down = f.contentY > m.lastY
            if (f.contentY !== m.lastY) m.lastDir = down ? 1 : -1
            m.lastY = f.contentY
            idle.restart()
            // Only scrolling down enters. Computed here: the progress binding may not have
            // updated yet.
            if (down && !m.galleryMode && m.usable && f.contentY >= m.endY - 0.5) {
                m.view.toTop()
                m.galleryMode = true
                m.entered()
            }
        }
    }
    function lerp(a, b, t) { return a + (b - a) * t }
    function rectIn(item) {
        return item ? item.mapToItem(m, 0, 0, item.width, item.height) : Qt.rect(0, 0, 0, 0)
    }

    readonly property rect shotFrom: { flick ? flick.contentY : 0; level; width; height; return rectIn(shot) }
    readonly property rect shotTo: { level; width; height; return rectIn(view ? view.firstShot : null) }
    readonly property rect buttonFrom: { level; width; height; return rectIn(button) }
    readonly property rect buttonTo: { level; width; height; return rectIn(view ? view.actionItem : null) }
    readonly property var media: gallery && gallery.media && gallery.media.length ? gallery.media[0] : null

    MediaTile {
        visible: m.morphing && !!m.media
        x: m.lerp(m.shotFrom.x, m.shotTo.x, m.level)
        y: m.lerp(m.shotFrom.y, m.shotTo.y, m.level)
        width: m.lerp(m.shotFrom.width, m.shotTo.width, m.level)
        height: m.lerp(m.shotFrom.height, m.shotTo.height, m.level)
        media: m.media
        loadWidth: m.shotTo.width  // its final size, so it doesn't reload as it grows
    }

    Rectangle {
        visible: m.morphing && !!m.button && m.button.visible
        x: m.lerp(m.buttonFrom.x, m.buttonTo.x, m.level)
        y: m.lerp(m.buttonFrom.y, m.buttonTo.y, m.level)
        width: m.lerp(m.buttonFrom.width, m.buttonTo.width, m.level)
        height: m.lerp(m.buttonFrom.height, m.buttonTo.height, m.level)
        radius: Ui.radiusMedium
        color: Backend.theme.accent.accent
        opacity: m.button && m.button.enabled ? 1 : 0.45
        clip: true
        Row {
            anchors.centerIn: parent
            spacing: Ui.gapS
            CIcon {
                visible: !!m.button && m.button.icon.name !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: m.lerp(22, 18, m.level)
                height: width
                source: m.button ? m.button.icon.name : ""
                isMask: true
                color: Backend.theme.accent.accentText
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: m.button ? m.button.text : ""
                color: Backend.theme.accent.accentText
                font.family: Ui.fontButtons
                font.weight: Font.Black
                font.pixelSize: m.lerp(Ui.textLead + 2, Ui.textBody, m.level)
            }
        }
    }
}
