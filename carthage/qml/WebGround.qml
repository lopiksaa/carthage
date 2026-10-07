// The glass look's ground: assets/ground/ground.html, drawn with WebGL 2 in a web view.
// Settings → Appearance → Background picks the variant; the colours come from the hardware
// colour's hue, in night or day. It stops while Carthage isn't the active window, while a game
// runs and with animations off. Glass panes frost it like anything else (it's an ordinary item).
import QtQuick
import QtWebEngine
import Carthage

Item {
    id: wg

    readonly property var g: Backend.theme.glass
    readonly property string variantName: Backend.settings.background || "studio"
    readonly property int variant: ({ still: 0, studio: 1, rays: 2, mesh: 3, iris: 4, topo: 5 })[variantName] ?? 1
    readonly property bool moving: variant !== 0 && Backend.motion > 0
                                   && (Qt.application.state === Qt.ApplicationActive || Backend.testNoFocus)
                                   && Backend.sessions.count === 0
    // The hue of the hardware colour (its accent); grey hardware gets a cool blue-violet.
    readonly property real hue: {
        const c = Qt.color(g.accent)
        return c.hsvSaturation < 0.12 ? 265 : c.hsvHue * 360
    }
    property bool ready: false

    function push() {
        if (!ready) return
        web.runJavaScript("setGround(" + JSON.stringify({
            variant: variant, dark: Backend.theme.dark ? 1 : 0, hue: hue,
            chroma: Backend.theme.dark ? 0.12 : 0.10, speed: Math.max(0, Backend.motion), moving: moving
        }) + ")")
    }
    onVariantChanged: push()
    onHueChanged: push()
    onMovingChanged: push()
    Connections { target: Backend.theme; function onChanged() { wg.push() } }

    // Until the page is up (a fraction of a second at start), the plain ground colour.
    Rectangle { anchors.fill: parent; color: wg.g.bg }

    WebEngineView {
        id: web
        anchors.fill: parent
        opacity: wg.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        backgroundColor: wg.g.bg
        url: Qt.resolvedUrl("../assets/ground/ground.html")
        settings.javascriptCanAccessClipboard: false
        settings.localContentCanAccessRemoteUrls: false
        settings.showScrollBars: false
        // It's only a picture: the window's own items take every click and key.
        enabled: false
        onLoadingChanged: (r) => {
            if (r.status === WebEngineView.LoadSucceededStatus) { wg.ready = true; wg.push() }
        }
    }
}
