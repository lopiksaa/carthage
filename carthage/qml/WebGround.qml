// The glass look's ground: assets/ground/ground.html, drawn with WebGL 2 in a web view.
// Settings → Appearance → Background picks the variant and Background Colors its colours, in
// night or day. It stops while Carthage isn't the active window, while a game
// runs and with animations off. Glass panes frost it like anything else (it's an ordinary item).
import QtQuick
import QtWebEngine
import Carthage

Item {
    id: wg

    readonly property var g: Backend.theme.glass
    readonly property string variantName: Backend.settings.background || "mesh"
    // (Studio was a second Mesh: it shows as Mesh)
    readonly property int variant: ({ still: 0, studio: 3, rays: 2, mesh: 3, iris: 4, topo: 5 })[variantName] ?? 3
    // Settings → Appearance → Advanced (theme.py GROUND_TUNING), each within its range.
    readonly property var tuning: {
        const saved = Backend.settings.groundTuning || {}, o = {}
        for (const s of Backend.theme.groundTuningSpec) {
            const v = Number(saved[s.key])
            o[s.key] = saved[s.key] !== undefined && isFinite(v) ? Math.max(s.from, Math.min(s.to, v)) : s.default
        }
        return o
    }
    readonly property bool moving: variant !== 0 && Backend.motion > 0 && tuning.speed > 0
                                   && (Qt.application.state === Qt.ApplicationActive || Backend.testNoFocus)
                                   && Backend.sessions.count === 0 && !Ui.resizing && !Ui.groundCovered
    // Background Colors (theme.py GROUNDS, with Advanced's colours): four hues, their strength,
    // a tone and a lift; the mode sets the lightness.
    readonly property var colours: Backend.theme.ground
    property bool ready: false

    function push() {
        if (!ready || !view.item) return
        view.item.runJavaScript("setGround(" + JSON.stringify(Object.assign({}, tuning, {
            variant: variant, dark: Backend.theme.dark ? 1 : 0,
            hues: colours.hues, chroma: colours.chroma, tone: colours.tone, lift: colours.lift,
            speed: Math.max(0, Backend.motion) * tuning.speed, moving: moving, blur: blur
        })) + ")")
    }
    readonly property real blur: Math.max(0, Math.min(1, Backend.settings.groundBlur || 0))
    onVariantChanged: push()
    onMovingChanged: push()
    onTuningChanged: push()
    onBlurChanged: push()
    Connections { target: Backend.theme; function onChanged() { wg.push() } }

    // The web engine can lose its GPU context (a race in its texture sharing, seen while the
    // window resized): the page then stayed white. A new web view draws again.
    function rebuild() {
        ready = false
        view.active = false
        view.active = true
    }
    Timer { id: rebuildSoon; interval: 400; onTriggered: wg.rebuild() }

    // Until the page is up (a fraction of a second at start), the plain ground colour.
    Rectangle { anchors.fill: parent; color: wg.g.bg }

    Loader {
        id: view
        anchors.fill: parent
        // Hidden while the window is resized (Main.qml covers it), so nothing reads the web
        // engine's picture while it's being resized.
        visible: !Ui.resizing
        sourceComponent: WebEngineView {
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
            onJavaScriptConsoleMessage: (level, message) => {
                if (message.indexOf("CONTEXT_LOST_WEBGL") >= 0 || message.indexOf("ground: context lost") >= 0) rebuildSoon.restart()
            }
            onRenderProcessTerminated: rebuildSoon.restart()
        }
    }
}
