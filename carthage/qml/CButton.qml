// Carthage's button: rounded, soft, in the hardware's palette.
//   kind: "primary" (Play), "danger" (Quit), "plain", "ghost" (icon-only close etc.),
//         "scrim" (secondary actions over the dark backdrop of the closer look / store page),
//         "key" (a physical key on the hardware: its side shows under the face, it travels
//         keyDepth px when pressed; in the hardware's plastic)
//   glyph: "plus" / "more": drawn on the pixel grid in the label's weight (keys), instead of
//          an icon file (Breeze's 16-px icons blur and sit half a pixel off when scaled)
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: btn

    property string kind: "plain"
    property bool big: false
    property bool iconAfter: false // the icon after the text (a forward arrow: "All Categories →")
    property color tint: "transparent" // overrides the foreground, e.g. on a dark backdrop
    property string glyph: ""
    // For tooltips: true from a press until the pointer leaves (a tip popping up over what the
    // click just opened is noise). Use `ToolTip.visible: tipWanted`.
    property bool usedSinceHover: false
    onHoveredChanged: if (!hovered) usedSinceHover = false
    onPressedChanged: if (pressed) usedSinceHover = true
    readonly property bool tipWanted: hovered && !usedSinceHover
    // Even, so the face's centre (and everything on it) lands on whole pixels, up and down.
    readonly property int keyDepth: 4
    readonly property bool glassy: Backend.theme.glassy
    // How far a key's face (and its label) sits from centre: plastic keys stand on their side
    // wall and sink by keyDepth; glass keys have no wall and the pane itself moves 2 px down.
    readonly property real faceShift: !isKey ? 0 : glassy ? (down ? 2 : 0) : (down ? keyDepth / 2 : -keyDepth / 2)

    readonly property var pal: Backend.theme.p
    readonly property var acc: Backend.theme.accent
    readonly property bool isKey: kind === "key"
    // Disabled for itself, not only because the page is under an overlay (Ui.bodyBlocked).
    property bool inBody: false
    Component.onCompleted: {
        for (let p = parent; p; p = p.parent)
            if (p.objectName === "appBody") { inBody = true; break }
    }
    readonly property bool looksDisabled: !enabled && !(inBody && Ui.bodyBlocked)
    readonly property color fg: tint.a > 0 ? tint
                               : isKey ? pal.dockText
                               : kind === "primary" ? acc.accentText
                               : kind === "scrim" ? Ui.onScrim
                               : kind === "danger" ? pal.dangerText : pal.panelText

    implicitHeight: big ? Ui.controlHeightLarge : Ui.controlHeight
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (text ? (big ? 2 * Ui.gapXL : 2 * Ui.gapL) : 0))
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: text || icon.name
    Accessible.role: Accessible.Button

    scale: down && !isKey ? 0.97 : 1
    Behavior on scale {
        NumberAnimation { duration: 80 * Backend.motion; easing.type: Easing.OutQuad }
    }

    background: Item {
      // A raised key: its darker side shows under the face and disappears when pressed.
      GlassSurface { // glass: a pane with no side wall; pressing sinks it and tightens its shadow
        visible: btn.isKey && btn.glassy
        width: parent.width
        height: parent.height
        y: btn.faceShift
        radius: Ui.radiusMedium
        opacity: btn.looksDisabled ? 0.5 : 1
        sheen: btn.hovered ? Qt.alpha(g.sheen, Math.min(1, g.sheen.a * 1.8 + 0.04)) : g.sheen
        shadowY: btn.down ? 3 : 8
        shadowBlur: btn.down ? 8 : 18
        shadowSpread: btn.down ? -4 : -8
      }
      Rectangle { // soft shadow where the key meets the surface
        visible: btn.isKey && !btn.glassy
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -1
        radius: Ui.radiusMedium
        color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.35 : 0.15)
      }
      Rectangle { // the key's side
        visible: btn.isKey && !btn.glassy
        anchors.fill: parent
        radius: Ui.radiusMedium
        opacity: btn.looksDisabled ? 0.45 : 1
        color: Qt.darker(btn.pal.dockBottom, Backend.theme.dark ? 1.5 : 1.15)
      }
      Rectangle { // the face, lit from above
        id: keyFace
        visible: btn.isKey && !btn.glassy
        anchors.fill: parent
        anchors.topMargin: btn.down ? btn.keyDepth : 0
        anchors.bottomMargin: btn.down ? 0 : btn.keyDepth
        radius: Ui.radiusMedium
        opacity: btn.looksDisabled ? 0.45 : 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.tint(btn.pal.dockTop, Qt.rgba(1, 1, 1, btn.hovered ? 0.1 : 0.06)) }
            GradientStop { position: 1.0; color: btn.pal.dockBottom }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.2)
        Item { // shine along the top edge and round the corners, fading out halfway down
            visible: !btn.down
            anchors.fill: parent
            anchors.margins: 1
            anchors.bottomMargin: parent.height / 2
            clip: true
            Rectangle {
                width: parent.width
                height: keyFace.height - 2
                radius: Ui.radiusMedium - 1
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.1 : 0.4)
            }
        }
      }
      Rectangle {
        visible: !btn.isKey
        anchors.fill: parent
        radius: Ui.radiusMedium
        color: {
            if (btn.kind === "primary") return btn.hovered ? btn.acc.accentHover : btn.acc.accent
            if (btn.kind === "scrim") return btn.hovered ? Ui.scrimControlHover : Ui.scrimControl
            if (btn.kind === "ghost") return btn.hovered ? (btn.tint.a > 0 ? Ui.scrimControl : btn.pal.panelHover) : "transparent"
            return btn.hovered ? btn.pal.panelHover : Qt.alpha(btn.pal.panelHover, 0.6)
        }
        border.width: btn.kind === "danger" ? 1 : 0
        border.color: Qt.alpha(btn.pal.dangerText, 0.5)
        opacity: btn.looksDisabled ? 0.45 : 1
      }
      Rectangle {
        visible: btn.visualFocus
        anchors.fill: parent
        anchors.margins: btn.isKey ? -6 : -3
        radius: Ui.radiusMedium + (btn.isKey ? 6 : 3)
        color: "transparent"
        border.width: 2
        border.color: Ui.focusColor
      }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        opacity: btn.looksDisabled ? 0.4 : 1  // a button that can't be used looks it, label included
        transform: Translate { y: btn.faceShift }
        Row {
            id: row
            // On whole pixels (anchors.centerIn would put an odd leftover on a half pixel).
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            spacing: Ui.gapS
            layoutDirection: btn.iconAfter ? Qt.RightToLeft : Qt.LeftToRight
            Item {  // a drawn glyph: 2-px strokes, the weight of a bold label
                visible: btn.glyph !== ""
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { visible: btn.glyph === "plus"; x: 2; y: 8; width: 14; height: 2; radius: 1; color: btn.fg }
                Rectangle { visible: btn.glyph === "plus"; x: 8; y: 2; width: 2; height: 14; radius: 1; color: btn.fg }
                Repeater {
                    model: btn.glyph === "more" ? 3 : 0
                    Rectangle { required property int index; x: 7; y: 1 + index * 6; width: 4; height: 4; radius: 2; color: btn.fg }
                }
            }
            CIcon {
                visible: btn.icon.name !== "" && btn.glyph === ""
                anchors.verticalCenter: parent.verticalCenter
                width: btn.big ? 22 : 18
                height: width
                source: btn.icon.name
                isMask: true
                color: btn.fg
            }
            Text {
                visible: btn.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                color: btn.fg
                font.family: Ui.fontButtons
                font.weight: btn.kind === "primary" ? Font.Black : Font.Bold
                font.pixelSize: btn.big ? Ui.textLead + 2 : Ui.textBody
            }
        }
    }
}
