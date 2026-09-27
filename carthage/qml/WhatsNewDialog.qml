// "What's new in Carthage": shown once after an update (Backend.whatsNew), and from Menu →
// System → What's new. Built like the setup wizard (step dots, title, text, Back / Next), one
// step per change, each with a picture: the change's icon on a plastic tile that bobs, with a
// ring pulsing out and a shine passing over. (Fixes stay in the GitHub notes.)
// The notes come from whatsnew.py, the same text as the GitHub release notes.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property Item appRoot
    property var notes: ({})
    property bool afterUpdate: false
    property int step: 0
    readonly property var slides: notes.slides || []
    readonly property int lastStep: slides.length - 1
    readonly property var cur: slides[step] || {}
    readonly property real motion: Backend.motion

    function openWith(n, fromUpdate) {
        if (!n || !n.version) return
        notes = n
        afterUpdate = fromUpdate
        step = 0
        open()
        if (appRoot) appRoot.sound("pick")
    }
    function go(d) {
        const n = Math.max(0, Math.min(lastStep, step + d))
        if (n === step) return
        step = n
        if (appRoot) appRoot.sound("hover")
    }
    onClosed: if (afterUpdate) Backend.whatsNewSeen()
    onStepChanged: if (motion > 0) swap.restart()

    maxWidth: 520

    component Title_: Text {
        width: parent.width
        color: dlg.pal.panelText
        font.family: "Nunito"
        font.weight: Font.Black
        font.pixelSize: Ui.textTitle
        wrapMode: Text.Wrap
    }
    component Body_: Text {
        width: parent.width
        color: dlg.pal.panelTextDim
        font.family: "Nunito"
        font.pixelSize: Ui.textBody
        wrapMode: Text.Wrap
    }

    // The plastic each kind of change is molded in.
    function tileColor(kind) {
        return kind === "new" ? "#2fa84b" : kind === "changed" ? "#e08a1e" : Backend.theme.accent.accent
    }

    contentItem: Column {
        id: body
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: "What's new in Carthage " + (dlg.notes.version || "")
        focus: true
        Keys.onLeftPressed: dlg.go(-1)
        Keys.onRightPressed: dlg.go(1)

        // Step dots, like setup's, and the version.
        Item {
            width: parent.width
            height: 20
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: dlg.lastStep + 1
                    delegate: Rectangle {
                        required property int index
                        width: index === dlg.step ? 18 : 6
                        height: 6
                        radius: 3
                        color: index <= dlg.step ? Backend.theme.accent.accent : dlg.pal.panelBorder
                        Behavior on width { NumberAnimation { duration: 140 * dlg.motion } }
                    }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "WHAT'S NEW IN " + (dlg.notes.version || "")
                color: dlg.pal.panelTextDim
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textCaption
                font.letterSpacing: 1.6
            }
        }

        // The step: picture, title, text.
        Column {
            id: page
            width: parent.width
            spacing: Ui.gapM

            // A plastic tile with the change's icon.
            Item {
                id: picture
                width: parent.width
                height: 150
                Rectangle {
                    id: tile
                    anchors.centerIn: parent
                    width: 150
                    height: 150
                    radius: 28
                    // Rounded clip (plain `clip` only cuts the square box, and the shine showed
                    // in the corners).
                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4  // layers don't inherit the window's MSAA
                    layer.effect: RoundedMask { radius: tile.radius }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(dlg.tileColor(dlg.cur.kind), 1.28) }
                        GradientStop { position: 1.0; color: Qt.darker(dlg.tileColor(dlg.cur.kind), 1.18) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.3)
                    // Molded edge: light on the top, shade at the bottom (one light, top-left).
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                    }
                    // The ring that pulses out from the icon.
                    Rectangle {
                        id: ring
                        anchors.centerIn: parent
                        width: 70
                        height: 70
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.rgba(1, 1, 1, 0.55)
                        opacity: 0
                        SequentialAnimation on scale {
                            running: dlg.opened && dlg.motion > 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.8; to: 2.1; duration: 1400; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 600 }
                        }
                        SequentialAnimation on opacity {
                            running: dlg.opened && dlg.motion > 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.7; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 600 }
                        }
                    }
                    CIcon {
                        id: glyph
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - height) / 2 + bob.value
                        width: 64
                        height: 64
                        source: (dlg.cur.icon || "help-about") + "-symbolic"
                        color: "#ffffff"
                        QtObject { id: bob; property real value: 0 }
                        SequentialAnimation {
                            running: dlg.opened && dlg.motion > 0
                            loops: Animation.Infinite
                            NumberAnimation { target: bob; property: "value"; to: -6; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { target: bob; property: "value"; to: 0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    // A shine sweeping across now and then.
                    Rectangle {
                        id: shine
                        width: 46
                        height: parent.height * 2
                        y: -parent.height / 2
                        x: -80
                        rotation: 24
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                        }
                        SequentialAnimation on x {
                            running: dlg.opened && dlg.motion > 0
                            loops: Animation.Infinite
                            PauseAnimation { duration: 900 }
                            NumberAnimation { from: -80; to: 220; duration: 900; easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 1800 }
                        }
                    }
                }
                // The kind of change, as a sticker on the tile's corner.
                Rectangle {
                    x: tile.x + tile.width - width * 0.7
                    y: tile.y - height * 0.3
                    width: kindText.implicitWidth + 18
                    height: kindText.implicitHeight + 8
                    radius: height / 2
                    rotation: 8
                    antialiasing: true
                    smooth: true
                    // Drawn flat into its own texture, then turned as one image: rotated text
                    // otherwise kept its subpixel smoothing and showed color fringes.
                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4
                    layer.textureSize: Qt.size(width * 3 * Screen.devicePixelRatio, height * 3 * Screen.devicePixelRatio)
                    color: "#ffffff"
                    border.width: 2
                    border.color: dlg.tileColor(dlg.cur.kind)
                    Text {
                        id: kindText
                        anchors.centerIn: parent
                        text: dlg.cur.kind === "new" ? "NEW" : dlg.cur.kind === "changed" ? "CHANGED" : "FIXED"
                        color: Qt.darker(dlg.tileColor(dlg.cur.kind), 1.35)
                        font.family: "Nunito"
                        font.weight: Font.Black
                        font.pixelSize: Ui.textCaption
                        font.letterSpacing: 1.2
                        // Rotated with the sticker: glyphs drawn as curves (grayscale edges), since
                        // rotated subpixel-smoothed text shows color fringes.
                        renderType: Text.CurveRendering
                        antialiasing: true
                    }
                }
            }

            Title_ { text: dlg.cur.title || "" }
            Body_ { visible: text !== ""; text: dlg.cur.text || "" }
        }
        // Changing step: a quick fade and rise, as setup's steps just swap.
        ParallelAnimation {
            id: swap
            NumberAnimation { target: page; property: "opacity"; from: 0.2; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: tile; property: "scale"; from: 0.9; to: 1; duration: 240; easing.type: Easing.OutBack }
        }

        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            topPadding: 6
            CButton {
                visible: dlg.step > 0
                text: "Back"
                onClicked: dlg.go(-1)
            }
            CButton {
                kind: "primary"
                text: dlg.step >= dlg.lastStep ? "Got It" : "Next"
                onClicked: dlg.step >= dlg.lastStep ? dlg.close() : dlg.go(1)
            }
        }
    }
}
