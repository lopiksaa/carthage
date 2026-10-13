// The first launch: a splash with a cartridge that docks on "Run Setup", then the setup steps
// over the ground (what Carthage found, the look, the cartridge colour, the Steam and
// SteamGridDB keys). "Let's Play" reveals the library and `finished` starts the tour (Tour.qml).
//   firstRun.start(true)   (false: straight to the steps, no splash)
import QtQuick
import QtQuick.Shapes
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: fr

    property Item appRoot
    property Item ground          // the glass ground (App.qml), shown behind the setup
    property string phase: ""     // splash, docking, setup, leaving; "" = closed
    property int step: 0
    property int shownStep: 0      // the step on screen (follows step after the change animates)
    readonly property int lastStep: 5
    property var found: []
    readonly property var pal: Backend.theme.p
    readonly property string os: Qt.platform.os === "windows" ? "Windows Credential Manager"
                                 : Qt.platform.os === "osx" ? "the macOS Keychain" : "your system's keyring"
    signal finished()
    // The demo cartridge (the 3D cards draw it from this, as a game).
    readonly property var demoGame: ({ gameId: "_demo", title: "", source: "carthage", sourceName: "CARTHAGE",
                                       sourceIcon: "carthage", label: "CRTHG - 8008135 - LPKS", installed: true })

    function start(withSplash) {
        found = Backend.launcherSummary()
        step = 0
        shownStep = 0
        opacity = 1
        splashCart.reset()
        splashCart.visible = true
        demoDock.hideY = demoDock.height + demoDock.protrude + 40
        phase = withSplash ? "splash" : "setup"
    }
    // The cartridge flies into the dock's slot the way a game does on Play (App.qml play()).
    function fly() {
        const card = { gameId: "_demo", title: "", source: "carthage", sourceName: "CARTHAGE", sourceIcon: "carthage",
                       labelOverride: "CRTHG - 8008135 - LPKS", installed: true }
        appRoot.pendingSeat["_demo"] = true
        demoDock.demoInsert(card)
        for (const k in card) if (k in flyer.cart) flyer.cart[k] = card[k]
        flyer.x = splashCart.x
        flyer.y = splashCart.y + splashCart.lift
        flyer.scale = 1
        flyer.lift = 0.6
        flyer.visible = true
        splashCart.visible = false
        const seat = demoDock.landingPos(0)
        flyer.launch(seat.x, seat.y, demoDock.cartW / flyer.cardWidth, function () {
            delete fr.appRoot.pendingSeat["_demo"]
            const s = demoDock.slotFor("_demo")
            if (s) s.seatIn()
            flyer.visible = false
        }, function () {
            const s = demoDock.slotFor("_demo")
            if (s) s.arriving = true
        })
    }
    function finish() {
        Backend.setupFinished()
        appRoot.introCards()
        phase = "leaving"
        leave.restart()
    }

    visible: phase !== ""
    anchors.fill: parent
    z: 980

    // Nothing behind takes the pointer while it's up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => w.accepted = true
    }
    NumberAnimation {
        id: leave
        target: fr
        property: "opacity"
        to: 0
        duration: 500 * Backend.motion
        easing.type: Easing.InOutCubic
        onFinished: { fr.phase = ""; fr.finished() }
    }

    // The ground behind: the glass look's own (live), or plastic's tray.
    Rectangle {
        anchors.fill: parent
        color: Backend.theme.glassy ? Backend.theme.glass.bg : fr.pal.tray
    }
    ShaderEffectSource {
        anchors.fill: parent
        visible: Backend.theme.glassy && !!fr.ground
        sourceItem: visible ? fr.ground : null
        live: true
    }

    component Title_: Text {
        width: parent.width
        color: fr.pal.trayText
        font.family: Ui.fontText
        font.weight: Font.Black
        font.pixelSize: Ui.textTitle
        wrapMode: Text.Wrap
    }
    component Body_: Text {
        width: parent.width
        color: fr.pal.panelTextDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textBody
        wrapMode: Text.Wrap
        lineHeight: 1.15
    }
    component Caption_: Text {
        color: fr.pal.panelTextDim
        font.family: Ui.fontText
        font.weight: Font.Bold
        font.pixelSize: Ui.textCaption
    }

    // A line, a lock, a line: the lock opens (with a little pop) once that service's key is saved.
    component KeyLock: Row {
        id: kl
        property string service
        readonly property bool open: Backend.keys.has[service] === true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: Ui.gapM
        onOpenChanged: if (open && Backend.motion > 0) pop.restart()
        readonly property color ink: open ? Backend.theme.led.green : fr.pal.panelTextDim
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 140; height: 1; color: kl.ink; opacity: 0.5 }
        CIcon {
            id: lockIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: kl.open ? "lock-open-symbolic" : "lock-symbolic"
            color: kl.ink
        }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 140; height: 1; color: kl.ink; opacity: 0.5 }
        SequentialAnimation {
            id: pop
            NumberAnimation { target: lockIcon; property: "scale"; to: 1.4; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: lockIcon; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
        }
    }

    // A labelled row of the Appearance step: the label left, the control right.
    component Line: Item {
        id: ln
        property string label
        default property alias content: holder.data
        width: parent.width
        height: 40
        Caption_ { anchors.verticalCenter: parent.verticalCenter; text: ln.label }
        Item { id: holder; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }

    // ---- The splash ----
    Item {
        anchors.fill: parent
        visible: fr.phase === "splash" || fr.phase === "docking"

        Column {
            id: welcome
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(32, parent.height * 0.1)
            spacing: Ui.gapS
            opacity: fr.phase === "splash" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 * Backend.motion } }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome to Carthage!"
                color: fr.pal.trayText
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle * 1.5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press Run Setup to get started."
                color: fr.pal.trayTextDim
                font.family: Ui.fontText
                font.pixelSize: Ui.textBody
            }
        }
        HeroCard {
            id: splashCart
            game: fr.demoGame
            amp: 5
            readonly property real homeY: (parent.height - height) / 2 - 10
            // (bindings again, not values: at first launch the window has no size yet)
            function reset() { y = Qt.binding(() => homeY); scale = 1 }
            width: Math.min(220, parent.height * 0.3)
            anchors.horizontalCenter: parent.horizontalCenter
            y: homeY
            z: 1
        }
        CButton {
            id: runButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: splashCart.homeY + splashCart.height + 44
            kind: "primary"
            text: "Run Setup"
            icon.name: "media-playback-start-symbolic"
            opacity: fr.phase === "splash" ? 1 : 0
            enabled: fr.phase === "splash"
            Behavior on opacity { NumberAnimation { duration: 220 * Backend.motion } }
            onClicked: { fr.phase = "docking"; fr.appRoot.sound("key"); docking.restart() }
        }

        // The real dock (bare: just its slot) rises, the cartridge flies into it as a game does
        // on Play and seats with the flaps, then the dock slides away with it.
        Dock {
            id: demoDock
            demo: true
            appRoot: fr.appRoot
            behind: Backend.theme.glassy && fr.ground ? [fr.ground] : []
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            z: 2
            hideY: height + protrude + 40
        }
        Flyer {
            id: flyer
            visible: false
            z: 3
            motion: Backend.motion
            cardWidth: splashCart.width
        }
        SequentialAnimation {
            id: docking
            NumberAnimation { target: demoDock; property: "hideY"; to: 0; duration: 520 * Backend.motion; easing.type: Easing.OutCubic }
            ScriptAction { script: fr.fly() }
            PauseAnimation { duration: 1500 * Backend.motion }
            // It flies down: a small lift as it lets go, then the fall, out of the window.
            NumberAnimation { target: demoDock; property: "hideY"; to: -10; duration: 140 * Backend.motion; easing.type: Easing.OutQuad }
            NumberAnimation { target: demoDock; property: "hideY"; to: demoDock.height + demoDock.protrude + 60; duration: 380 * Backend.motion; easing.type: Easing.InCubic }
            ScriptAction { script: fr.phase = "setup" }
        }
    }

    // ---- The setup steps ----
    Item {
        id: panel
        visible: fr.phase === "setup" || fr.phase === "leaving"
        width: Math.min(760, fr.width - 48)
        height: body.implicitHeight + 2 * 28
        // (it grows or shrinks to each step evenly, top and bottom, while the content slides sideways)
        Behavior on height { NumberAnimation { duration: 220 * Backend.motion; easing.type: Easing.InOutCubic } }
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shift
        // Arriving: it slides in from the right as it fades in (sideways only, like the steps).
        property real shift: 0
        Connections {
            target: fr
            function onPhaseChanged() { if (fr.phase === "setup") arrive.restart() }
        }
        ParallelAnimation {
            id: arrive
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 380 * Backend.motion; easing.type: Easing.OutQuad }
            NumberAnimation { target: panel; property: "shift"; from: 48; to: 0; duration: 460 * Backend.motion; easing.type: Easing.OutCubic }
        }
        PanelBackground { anchors.fill: parent; radius: 22; frosts: fr.ground ? [fr.ground] : [] }

        Column {
            id: body
            x: 28
            y: 28
            width: parent.width - 56
            spacing: Ui.gapM
            // Changing step, in order: the old step slides away and fades out, then the panel
            // resizes to the new one (shownStep switches it), then the new step slides in from
            // the side you're going to.
            property real slide: 0
            transform: Translate { x: body.slide }
            Connections {
                target: fr
                function onStepChanged() {
                    if (fr.phase !== "setup" || Backend.motion <= 0) { fr.shownStep = fr.step; return }
                    stepSwap.dir = fr.step >= fr.shownStep ? 1 : -1
                    stepSwap.restart()
                }
            }
            SequentialAnimation {
                id: stepSwap
                property int dir: 1
                ParallelAnimation {
                    NumberAnimation { target: body; property: "slide"; to: -24 * stepSwap.dir; duration: 130 * Backend.motion; easing.type: Easing.InQuad }
                    NumberAnimation { target: body; property: "opacity"; to: 0; duration: 130 * Backend.motion; easing.type: Easing.InQuad }
                }
                ScriptAction { script: fr.shownStep = fr.step }
                PauseAnimation { duration: 230 * Backend.motion }  // the panel's resize
                ParallelAnimation {
                    NumberAnimation { target: body; property: "slide"; from: 36 * stepSwap.dir; to: 0; duration: 280 * Backend.motion; easing.type: Easing.OutCubic }
                    NumberAnimation { target: body; property: "opacity"; to: 1; duration: 220 * Backend.motion; easing.type: Easing.OutQuad }
                }
            }

            Row {  // where you are
                spacing: 6
                Repeater {
                    model: fr.lastStep + 1
                    delegate: Rectangle {
                        required property int index
                        width: index === fr.step ? 18 : 6
                        height: 6
                        radius: 3
                        color: index <= fr.step ? Backend.theme.accent.accent : Qt.alpha(fr.pal.panelText, 0.28)
                        Behavior on width { NumberAnimation { duration: 140 * Backend.motion; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // 0: what it found
            Column {
                visible: fr.shownStep === 0
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "Welcome to Carthage"; color: fr.pal.panelText }
                Body_ {
                    text: fr.found.length ? "Carthage is a game launcher that unifies your libraries in one. Here's what it found:"
                        : "Carthage is a game launcher that unifies your libraries in one. It didn't find any launchers yet: it reads Steam, Epic, Battle.net, Heroic and Lutris once they're installed, and you can add any game by hand."
                }
                Column {
                    visible: fr.found.length > 0
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: fr.found
                        delegate: Row {
                            required property var modelData
                            spacing: Ui.gapM
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                source: "image://gc/launcher/" + (modelData.source || "other") + "/" + fr.pal.panelText.toString().replace("#", "")
                                sourceSize: Qt.size(36, 36)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name + "  ·  " + modelData.count + (modelData.count === 1 ? " game" : " games")
                                color: fr.pal.panelText
                                font.family: Ui.fontText
                                font.weight: Font.Bold
                                font.pixelSize: Ui.textBody
                            }
                        }
                    }
                }
            }

            // 1: the look
            Column {
                visible: fr.shownStep === 1
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "Appearance"; color: fr.pal.panelText }
                Line {
                    label: "Mode"
                    CSegmented {
                        width: 200
                        height: 34
                        Accessible.name: "Mode"
                        value: Backend.theme.dark ? "dark" : "light"
                        options: [{ value: "dark", text: "Dark" }, { value: "light", text: "Light" }]
                        onPicked: (v) => { Backend.settings.themeMode = v; fr.appRoot.sound("key") }
                    }
                }
                Line {
                    label: "Theme"
                    CSegmented {
                        width: 200
                        height: 34
                        Accessible.name: "Theme"
                        value: Backend.theme.look
                        options: [{ value: "glass", text: "Glass" }, { value: "plastic", text: "Plastic" }]
                        onPicked: (v) => { Backend.settings.look = v; fr.appRoot.sound("key") }
                    }
                }
                Line {
                    visible: Backend.theme.glassy
                    label: "Background"
                    CSegmented {
                        width: 470
                        height: 34
                        Accessible.name: "Background"
                        value: ["mesh", "rays", "iris", "topo", "still"].indexOf(Backend.settings.background) >= 0 ? Backend.settings.background : "mesh"
                        options: [{ value: "mesh", text: "Mesh" }, { value: "rays", text: "Underwater" }, { value: "iris", text: "Holographic" },
                                  { value: "topo", text: "Contours" }, { value: "still", text: "Still" }]
                        onPicked: (v) => { Backend.settings.background = v; fr.appRoot.sound("key") }
                    }
                }
                Line {
                    label: Backend.theme.glassy ? "Colors" : "Theme color"
                    Row {
                        visible: Backend.theme.glassy
                        spacing: Ui.gapS
                        Repeater {
                            model: Backend.theme.groundOptions
                            delegate: ColorChip {
                                required property var modelData
                                size: 30
                                label: "Background colors: " + modelData.text
                                colors: modelData.colors
                                selected: !Backend.theme.groundCustom && Backend.theme.groundColors === modelData.value
                                onPicked: { Backend.settings.groundColors = modelData.value; fr.appRoot.sound("key") }
                            }
                        }
                    }
                    Row {
                        visible: !Backend.theme.glassy
                        spacing: Ui.gapS
                        Repeater {
                            model: Backend.theme.hardwareOptions.filter(o => o.suggested)
                            delegate: ColorChip {
                                required property var modelData
                                size: 30
                                label: "Theme color: " + modelData.text
                                plastic: modelData.color
                                selected: Backend.settings.hardware === modelData.value
                                onPicked: { Backend.settings.hardware = modelData.value; fr.appRoot.sound("key") }
                            }
                        }
                    }
                }
            }

            // 2: the cartridges' colour, on a cartridge that jumps when it changes
            Column {
                visible: fr.shownStep === 2
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "Game card color"; color: fr.pal.panelText }
                Item {
                    width: parent.width
                    height: 250
                    HeroCard {
                        id: colorCart
                        game: fr.demoGame
                        amp: 4
                        width: 150
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        x: 260
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Ui.gapM
                        Body_ { text: "Choose how your game cards will look like:" }
                        Grid {
                            columns: 5
                            spacing: Ui.gapS
                            Repeater {
                                model: Backend.theme.hardwareOptions.filter(o => o.suggested)
                                delegate: ColorChip {
                                    required property var modelData
                                    size: 36
                                    label: "Cartridge color: " + modelData.text
                                    plastic: modelData.color
                                    selected: Backend.theme.cardValue === modelData.value && Backend.settings.cardColor !== "auto"
                                    onPicked: {
                                        if (Backend.settings.cardColor !== modelData.value) colorCart.jump()
                                        Backend.settings.cardColor = modelData.value
                                        fr.appRoot.sound("key")
                                    }
                                }
                            }
                            ColorChip {
                                size: 36
                                label: "Cartridge color: pick any color"
                                rainbow: true
                                onPicked: fr.appRoot.pickColor("card")
                            }
                        }
                    }
                }
            }

            // 3: Steam, with what the key unlocks
            Column {
                visible: fr.shownStep === 3
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "Steam"; color: fr.pal.panelText }
                Rectangle {
                    width: parent.width
                    height: 214
                    radius: 14
                    color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.3 : 0.08)
                    Column {
                        x: 24
                        y: 18
                        width: parent.width - 48
                        spacing: 9
                        Repeater {
                            model: [["starred", "Steam Achievements"], ["download", "Games you own but haven't installed"],
                                    ["bookmark", "Steam Wishlist"], ["chronometer", "Steam playtime"],
                                    ["group", "Steam Family Library"]]
                            delegate: Row {
                                required property var modelData
                                spacing: Ui.gapM
                                CIcon { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; source: modelData[0] + "-symbolic"; color: fr.pal.panelTextDim }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    color: fr.pal.panelText
                                    font.family: Ui.fontText
                                    font.weight: Font.Bold
                                    font.pixelSize: Ui.textBody
                                }
                            }
                        }
                    }
                    KeyLock { service: "steam" }
                }
                Body_ { text: "To unlock these features, Carthage needs your Steam Web API key."; color: fr.pal.panelText }
                KeyRow {
                    width: parent.width
                    service: "steam"
                    title: "Steam Web API key"
                    getUrl: "https://steamcommunity.com/dev/apikey"
                    getText: "Get it here"
                }
                Caption_ {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.weight: Font.Normal
                    text: "Your keys are stored safely in " + fr.os + " and are only used for the features above."
                }
            }

            // 4: SteamGridDB, with a little scene of picking art
            Column {
                visible: fr.shownStep === 4
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "SteamGridDB"; color: fr.pal.panelText }
                Rectangle {
                    id: scene
                    width: parent.width
                    height: 214
                    radius: 14
                    color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.3 : 0.08)
                    clip: true
                    readonly property var swatches: [["#ff8a5c", "#7b2ff7"], ["#1fd1a5", "#1b4dd8"], ["#ffd23f", "#ee4266"], ["#5ad1ff", "#3a0ca3"]]
                    property int target: 0
                    property int shown: -1
                    Grid {
                        id: tiles
                        x: parent.width / 2 - width - 60
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -12  // (room for the lock below)
                        columns: 2
                        spacing: 12
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 66
                                height: 66
                                radius: 9
                                scale: scene.shown === index && press.running ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                border.width: scene.shown === index ? 2 : 0
                                border.color: "white"
                                gradient: Gradient {
                                    GradientStop { position: 0; color: scene.swatches[index][0] }
                                    GradientStop { position: 1; color: scene.swatches[index][1] }
                                }
                            }
                        }
                    }
                    Shape {  // the pointer
                        id: pointer
                        z: 2
                        width: 14
                        height: 20
                        x: tiles.x + 40
                        y: tiles.y + 40
                        ShapePath {
                            strokeColor: "#15161a"
                            strokeWidth: 1.2
                            fillColor: "white"
                            PathSvg { path: "M1 1 L1 17 L5 13 L8 19.5 L10.5 18.5 L7.5 12 L13 12 Z" }
                        }
                    }
                    Cartridge {  // the library's cartridge, its picture the tile just picked
                        id: sceneCart
                        width: 108
                        x: parent.width / 2 + 60
                        y: (parent.height - height) / 2 - 14 + hopY
                        property real hopY: 0
                        function jump() { hopAnim.restart() }
                        SequentialAnimation {
                            id: hopAnim
                            NumberAnimation { target: sceneCart; property: "hopY"; to: -10; duration: 110; easing.type: Easing.OutQuad }
                            NumberAnimation { target: sceneCart; property: "hopY"; to: 0; duration: 300; easing.type: Easing.OutBounce }
                        }
                        gameId: "_demo"
                        source: "carthage"
                        sourceName: "CARTHAGE"
                        sourceIcon: "carthage"
                        labelOverride: "CRTHG - 8008135 - LPKS"
                        Rectangle {
                            readonly property rect r: sceneCart.rect(sceneCart.geo.art)
                            visible: scene.shown >= 0
                            x: r.x
                            y: r.y
                            width: r.width
                            height: r.height
                            gradient: Gradient {
                                GradientStop { position: 0; color: scene.shown >= 0 ? scene.swatches[scene.shown][0] : "black" }
                                GradientStop { position: 1; color: scene.shown >= 0 ? scene.swatches[scene.shown][1] : "black" }
                            }
                        }
                    }
                    CIcon {  // a sparkle as the new picture lands
                        id: sparkle
                        z: 3
                        width: 30
                        height: 30
                        x: sceneCart.x + sceneCart.width * 0.62
                        y: sceneCart.y + sceneCart.height * 0.22
                        source: "sparkles-symbolic"
                        color: "white"
                        opacity: 0
                        SequentialAnimation {
                            id: sparkleAnim
                            ParallelAnimation {
                                NumberAnimation { target: sparkle; property: "opacity"; from: 0; to: 1; duration: 140 }
                                NumberAnimation { target: sparkle; property: "scale"; from: 0.4; to: 1.2; duration: 220; easing.type: Easing.OutBack }
                            }
                            NumberAnimation { target: sparkle; property: "opacity"; to: 0; duration: 420 }
                        }
                    }
                    // Every 1.7 s the pointer goes to the next tile and clicks it; the cartridge takes
                    // that picture with a sparkle.
                    Timer {
                        running: fr.shownStep === 4 && fr.phase === "setup" && Backend.motion > 0
                        interval: 1700
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            scene.target = (scene.target + 1) % 4
                            moveX.to = tiles.x + (scene.target % 2) * 78 + 38
                            moveY.to = tiles.y + Math.floor(scene.target / 2) * 78 + 38
                            move.restart()
                        }
                    }
                    ParallelAnimation {
                        id: move
                        NumberAnimation { id: moveX; target: pointer; property: "x"; duration: 650; easing.type: Easing.InOutCubic }
                        NumberAnimation { id: moveY; target: pointer; property: "y"; duration: 650; easing.type: Easing.InOutCubic }
                        onFinished: press.restart()
                    }
                    SequentialAnimation {
                        id: press
                        NumberAnimation { target: pointer; property: "scale"; to: 0.82; duration: 90 }
                        ScriptAction { script: { scene.shown = scene.target; sparkleAnim.restart(); sceneCart.jump() } }
                        NumberAnimation { target: pointer; property: "scale"; to: 1; duration: 120 }
                    }
                    KeyLock { service: "steamgrid"; z: 4 }
                }
                Body_ { text: "Carthage can link with SteamGridDB, so you can pick between different art for your games and fetch art that isn't available anywhere else (for games you add yourself, for example)." }
                KeyRow {
                    width: parent.width
                    service: "steamgrid"
                    title: "SteamGridDB API key"
                    getUrl: "https://www.steamgriddb.com/profile/preferences/api"
                    getText: "Get it here"
                }
                Caption_ {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.weight: Font.Normal
                    text: "Your keys are stored safely in " + fr.os + " and are only used for the features above."
                }
            }

            // 5: done
            Column {
                visible: fr.shownStep === 5
                width: parent.width
                spacing: Ui.gapM
                Title_ { text: "You're all set!"; color: fr.pal.panelText }
            }

            Row {
                anchors.right: parent.right
                spacing: Ui.gapM
                topPadding: 6
                CButton {
                    visible: fr.shownStep > 0
                    text: "Back"
                    onClicked: if (!stepSwap.running) fr.step--
                }
                CButton {
                    kind: "primary"
                    // (the step on screen: the label changes with the content, not before it)
                    text: fr.shownStep === 0 ? "Continue" : fr.shownStep === fr.lastStep ? "Let's Play" : "Next"
                    onClicked: {
                        if (stepSwap.running) return
                        fr.appRoot.sound("key")
                        if (fr.step >= fr.lastStep) fr.finish()
                        else fr.step++
                    }
                }
            }
        }
    }
}
