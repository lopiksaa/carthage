// Carthage's dialog: a panel centered over the window with everything behind it dimmed,
// fading and growing in. Every dialog is one of these, so they all open, close and look
// the same. `maxWidth` caps the width (it always stays 24 px clear of the window's edges).
//   CDialog { maxWidth: 400; contentItem: Column { … } }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Popup {
    property int maxWidth: 460
    readonly property var pal: Backend.theme.p

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(maxWidth, parent ? parent.width - 48 : maxWidth)
    padding: Ui.gapXL
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    QQC2.Overlay.modal: Rectangle { color: Backend.theme.p.scrim }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 * Backend.motion }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 160 * Backend.motion; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 * Backend.motion }
    }

    background: PanelBackground {}
}
