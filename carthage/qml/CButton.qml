// Carthage's button: rounded, soft, in the hardware's palette.
//   kind: "primary" (Play), "danger" (Quit), "plain", "ghost" (icon-only close etc.),
//         "scrim" (secondary actions over the dark backdrop of the closer look / store page),
//         "key" (a physical key on the hardware: sits in a well, travels 3 px when pressed;
//         in the hardware's plastic)
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: btn

    property string kind: "plain"
    property bool big: false
    property bool iconAfter: false // the icon after the text (a forward arrow: "All Categories →")
    property color tint: "transparent" // overrides the foreground, e.g. on a dark backdrop

    readonly property var pal: Backend.theme.p
    readonly property var acc: Backend.theme.accent
    readonly property bool isKey: kind === "key"
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
        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
    }

    background: Item {
      // A raised key: its darker side shows under the face and disappears when pressed.
      Rectangle { // soft shadow where the key meets the surface
        visible: btn.isKey
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -1
        radius: Ui.radiusMedium
        color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.35 : 0.15)
      }
      Rectangle { // the key's side
        visible: btn.isKey
        anchors.fill: parent
        radius: Ui.radiusMedium
        opacity: btn.enabled ? 1 : 0.45
        color: Qt.darker(btn.pal.dockBottom, Backend.theme.dark ? 1.5 : 1.15)
      }
      Rectangle { // the face, lit from above
        id: keyFace
        visible: btn.isKey
        anchors.fill: parent
        anchors.topMargin: btn.down ? 3 : 0
        anchors.bottomMargin: btn.down ? 0 : 3
        radius: Ui.radiusMedium
        opacity: btn.enabled ? 1 : 0.45
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
        opacity: btn.enabled ? 1 : 0.45
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
        opacity: btn.enabled ? 1 : 0.4  // a button that can't be used looks it, label included
        transform: Translate { y: btn.isKey ? (btn.down ? 1.5 : -1.5) : 0 }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Ui.gapS
            layoutDirection: btn.iconAfter ? Qt.RightToLeft : Qt.LeftToRight
            CIcon {
                visible: btn.icon.name !== ""
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
