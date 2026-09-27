// One cartridge: the pre-rendered shell with live art, header and label on top.
// Used in the tray, in flight and in the dock. Geometry comes from theme.py (600-wide
// reference canvas), so the shell image and these live parts always line up.
import QtQuick
import Carthage
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: cart

    property string gameId
    property string title
    property string source
    property string sourceName
    property string sourceIcon
    property string code
    property string extId
    property bool installed: true
    property bool noSlot: false
    // Optional "gameId" or "gameId/off" set in one step by the parent, so a not-installed
    // game's art never loads in color first.
    property string artKey: ""
    property string artUrl: ""
    property string labelOverride: ""
    property real labelSize: 40
    property string artFallback: ""

    // Install progress (0..1) while Steam installs this game, else -1.
    readonly property real installing: !cart.installed && Backend.installs && cart.gameId
                                       && Backend.installs.progress[cart.gameId] !== undefined
                                       ? Backend.installs.progress[cart.gameId] : -1
    property real fill: installing >= 0 ? installing : 0
    Behavior on fill { NumberAnimation { duration: 1900; easing.type: Easing.OutCubic } }
    property bool flat: false

    property bool glare: false
    property point glarePoint: Qt.point(width * 0.3, height * 0.2)
    property real glareStrength: 0

    readonly property var pal: Backend.theme.cp
    readonly property var geo: Backend.theme.geo
    readonly property string edition: Backend.theme.cardEdition
    readonly property real u: width / 600
    // Offscreen (as the 3D card's texture) there is no screen: fall back to 1.
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1

    height: width * Backend.theme.ratio

    // When the card is tilted, rotated or scaled, draw it flat into a texture first and
    // transform that: edges stay smooth instead of stair-stepping (no MSAA needed).
    property bool smoothTransform: false
    layer.enabled: smoothTransform
    layer.smooth: true
    layer.mipmap: true
    layer.textureSize: Qt.size(Math.ceil(width * dpr * 1.5), Math.ceil(height * dpr * 1.5))

    function rect(a) {
        return Qt.rect(a[0] * u, a[1] * u, a[2] * u, a[3] * u)
    }

    Image {
        id: shell
        anchors.fill: parent
        source: "image://gc/shell/" + cart.edition + (cart.flat ? "/flat" : "") + Backend.theme.texQuery
        sourceSize: Qt.size(Math.ceil(cart.width * cart.dpr), Math.ceil(cart.height * cart.dpr))
        asynchronous: !cart.flat
        smooth: true
    }

    Item {
        readonly property rect r: cart.rect(cart.geo.header)
        x: r.x
        y: r.y
        width: r.width
        height: r.height

        Image {
            anchors.fill: parent
            readonly property string mode: Backend.headerTick >= 0 && cart.gameId ? Backend.headerOf(cart.gameId) : "launcher"
            source: "image://gc/header/" + mode + "/" + (cart.source || "other") + "/" + cart.edition + "/"
                    + cart.gameId + "?h=" + Backend.headerTick + "&t=" + encodeURIComponent(cart.title)
            sourceSize: Qt.size(Math.ceil(width * cart.dpr), Math.ceil(height * cart.dpr))
            asynchronous: !cart.flat
            smooth: true
        }

        CIcon {
            visible: !cart.installed
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18 * cart.u
            width: 44 * cart.u
            height: width
            source: "download"
            isMask: true
            color: cart.pal.headerText
        }
        CIcon {
            visible: cart.noSlot
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 18 * cart.u
            width: 44 * cart.u
            height: width
            source: "system-run"
            isMask: true
            color: cart.pal.headerText
        }
    }

    Item {
        visible: art.wideArt
        x: art.x
        y: art.y
        width: art.width
        height: art.height
        clip: true
        Image {
            id: artBack
            anchors.fill: parent
            source: art.wideArt ? art.source : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(160, 90)
            smooth: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: artBack
            blurEnabled: true
            blur: 1.0
            blurMax: 32
            brightness: -0.15
            autoPaddingEnabled: false
        }
    }

    Image {
        id: art
        readonly property rect r: cart.rect(cart.geo.art)
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        // artTick changes whenever any art arrives; the source only changes for this game.
        readonly property int rev: Backend.artTick >= 0 ? Backend.artRevOf(cart.gameId) : 0
        // Store art: the URL, or once it fails, the next of the "|"-separated fallbacks. A
        // binding, never an assignment, so a cartridge reused for another game (the store
        // page's, the closer look's) follows the new game.
        readonly property var fallbacks: (cart.artFallback || "").split("|").filter(x => x)
        source: cart.artUrl ? (fallbackIndex >= 0 && fallbackIndex < fallbacks.length ? fallbacks[fallbackIndex] : cart.artUrl)
              : cart.artKey ? "image://gc/art/" + cart.artKey + "?r=" + rev + "&g=" + Backend.artGen
              : cart.gameId ? "image://gc/art/" + cart.gameId + (cart.installed ? "" : "/off")
                              + "?r=" + rev + "&g=" + Backend.artGen : ""
        sourceSize: Qt.size(Math.ceil(width * cart.dpr), Math.ceil(height * cart.dpr))
        verticalAlignment: cart.artUrl && !wideArt ? Image.AlignTop : Image.AlignVCenter
        // On error, try the next of the "|"-separated fallbacks. Wide banners (headers) are
        // shown whole rather than cropped.
        property int fallbackIndex: -1
        property bool wideArt: false
        onStatusChanged: {
            if (status === Image.Ready) wideArt = !!cart.artUrl && implicitWidth > implicitHeight * 1.6
            if (status === Image.Error && cart.artUrl && fallbackIndex + 1 < fallbacks.length) fallbackIndex++
        }
        Connections {
            target: cart
            function onArtUrlChanged() { art.fallbackIndex = -1; art.wideArt = false }
            function onArtFallbackChanged() { art.fallbackIndex = -1 }
        }
        fillMode: wideArt ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: !cart.flat
        smooth: true
    }

    Item {
        visible: cart.installing >= 0
        x: art.x
        y: art.y
        width: art.width
        height: art.height
        clip: true

        Item {
            id: fillBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(0, parent.height * cart.fill)
            clip: true
            Image {
                anchors.bottom: parent.bottom
                width: art.width
                height: art.height
                source: cart.installing >= 0 && cart.gameId
                        ? "image://gc/art/" + cart.gameId + "?r=" + art.rev + "&g=" + Backend.artGen : ""
                sourceSize: art.sourceSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
        Rectangle {
            id: glow
            anchors.left: parent.left
            anchors.right: parent.right
            y: parent.height - fillBox.height - height / 2
            height: Math.max(6, parent.height * 0.06)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on opacity {
                running: cart.installing >= 0 && cart.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }

    Text {
        readonly property rect r: cart.rect(cart.geo.label)
        x: r.x + 24 * cart.u
        y: r.y
        width: r.width - 48 * cart.u
        height: r.height
        text: cart.labelOverride ? cart.labelOverride
              : cart.installed
              ? (cart.sourceName + " - " + cart.extId + " - " + cart.code).toUpperCase()
              : cart.installing >= 0 ? "INSTALLING " + Math.round(cart.installing * 100) + "%"
              : "NOT INSTALLED"
        color: cart.pal.labelText
        font.family: "DM Mono"
        font.pixelSize: Math.max(1, cart.labelSize * cart.u)
        font.weight: cart.labelSize > 40 ? Font.Bold : Font.Normal
        font.letterSpacing: 2 * cart.u
        fontSizeMode: Text.HorizontalFit // long codes shrink to fit, like a printed label
        minimumPixelSize: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
    }

    Loader {
        anchors.fill: parent
        active: cart.glare && cart.glareStrength > 0.01
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: cart.glarePoint.x
                    centerY: cart.glarePoint.y
                    centerRadius: cart.width * 0.95
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.26 * cart.glareStrength) }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.07 * cart.glareStrength) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
                PathRectangle {
                    x: 1
                    y: 1
                    width: cart.width - 2
                    height: cart.height - 2
                    radius: cart.geo.radius * cart.u
                }
            }
        }
    }
}
