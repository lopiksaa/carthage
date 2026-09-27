// Carthage's button: rounded, soft, in the hardware's palette.
//   kind: "primary" (Play), "danger" (Quit), "plain", "ghost" (icon-only close etc.),
//         "scrim" (secondary actions over the dark backdrop of the closer look / store page),
//         "key" (a physical key on the hardware: sits in a well, travels 3 px when pressed;
//         the hardware's plastic, or black rubber in the Hi-Fi skin)
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: btn

    property string kind: "plain"
    property bool big: false
    property color tint: "transparent" // overrides the foreground, e.g. on a dark backdrop

    readonly property var pal: Backend.theme.p
    readonly property var acc: Backend.theme.accent
    readonly property bool isKey: kind === "key"
    readonly property bool rubber: isKey && Backend.theme.skin === "hifi"
    readonly property color fg: tint.a > 0 ? tint
                               : isKey ? (rubber ? "#e9e6e0" : pal.dockText)
                               : kind === "primary" ? acc.accentText
                               : kind === "scrim" ? Ui.onScrim
                               : kind === "danger" ? pal.dangerText : pal.panelText

    implicitHeight: big ? Ui.controlHeightLarge : Ui.controlHeight
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (text ? (big ? 2 * Ui.gapXL : 2 * Ui.gapL) : 0))
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: text || icon.name
    Accessible.role: Accessible.Button

    // Pressed buttons sink a little, like the cartridges do.
    scale: down && !isKey ? 0.97 : 1
    Behavior on scale {
        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
    }

    background: Item {
      // A key: the well it sits in, and the cap with its lip, which sinks when pressed.
      Rectangle {
        visible: btn.isKey
        anchors.fill: parent
        anchors.margins: -3
        anchors.topMargin: 0
        radius: Ui.radiusMedium + 3
        color: Qt.rgba(0, 0, 0, btn.rubber ? 0.55 : 0.4)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }
      }
      Rectangle {
        visible: btn.isKey
        anchors.fill: parent
        anchors.topMargin: btn.down ? 3 : 0
        anchors.bottomMargin: btn.down ? 0 : 3
        radius: Ui.radiusMedium
        opacity: btn.enabled ? 1 : 0.45
        gradient: Gradient {
            GradientStop { position: 0.0; color: btn.rubber ? (btn.hovered ? "#3a3a3a" : "#333333") : (btn.hovered ? Qt.lighter(btn.pal.dockTop, 1.05) : btn.pal.dockTop) }
            GradientStop { position: 1.0; color: btn.rubber ? "#1d1d1d" : btn.pal.dockBottom }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, btn.rubber ? 0.7 : (Backend.theme.dark ? 0.5 : 0.2))
        Rectangle { // the lit top edge
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            y: 1
            height: 1
            color: Qt.rgba(1, 1, 1, btn.rubber ? 0.12 : 0.18)
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
      // Focus ring, offset so it reads against any background.
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
        // A key's label rides down with the cap.
        transform: Translate { y: btn.isKey ? (btn.down ? 1.5 : -1.5) : 0 }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Ui.gapS
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
                font.family: "Nunito"
                font.weight: btn.kind === "primary" ? Font.Black : Font.Bold
                font.pixelSize: btn.big ? Ui.textLead + 2 : Ui.textBody
            }
        }
    }
}
