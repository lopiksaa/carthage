// Carthage's scrollbar: a slim rounded thumb and no track line, the same on every
// platform. It widens a little under the pointer. `onDark` for views over the dark
// backdrop (closer look, store page); otherwise it takes the panel/tray text color.
//   QQC2.ScrollBar.vertical: CScrollBar {}
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.ScrollBar {
    id: bar

    property bool onDark: false
    property color ink: onDark ? Ui.onScrim : Backend.theme.p.trayText

    padding: 3
    minimumSize: 0.08
    policy: size < 1 ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff
    // Hidden at rest: shown while scrolling, dragging or pointing at it, then fades out.
    readonly property bool busy: bar.active || bar.hovered || bar.pressed
    onBusyChanged: if (!busy) linger.restart()
    Timer { id: linger; interval: 900 }
    background: Item {}
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 8 : 5
        implicitHeight: implicitWidth
        radius: width / 2
        color: bar.ink
        opacity: !(bar.busy || linger.running) ? 0 : bar.pressed ? 0.55 : bar.hovered ? 0.4 : 0.22
        Behavior on implicitWidth { NumberAnimation { duration: 120 * Backend.motion } }
        Behavior on opacity { NumberAnimation { duration: 200 * Backend.motion } }
    }
}
