// A faint, slow drift so a held cartridge doesn't look pasted on. Off at animation speed
// "Instant". It rests while Carthage isn't the active window (nobody is looking), and it
// steps 30 times a second rather than every screen refresh: at this speed a step is a
// tenth of a pixel, so it looks the same and the graphics card gets to rest in between.
import QtQuick

Item {
    id: drift

    property bool active: false
    property real motion: 1

    readonly property real turn: Math.sin(phase) * maxTurn * amount
    readonly property real tip: Math.sin(phase * 2 + 1.3) * maxTip * amount
    readonly property real float: Math.sin(phase * 2) * maxFloat * amount

    readonly property real maxTurn: 1.0    // degrees
    readonly property real maxTip: 0.6     // degrees
    readonly property real maxFloat: 2     // pixels
    readonly property int period: 7000      // ms
    readonly property int fadeDuration: 1200        // ms

    property real amount: active && motion > 0 && Qt.application.state === Qt.ApplicationActive ? 1 : 0
    Behavior on amount { NumberAnimation { duration: drift.fadeDuration; easing.type: Easing.InOutSine } }
    property real phase: 0
    Timer {
        property real last: 0
        running: drift.amount > 0
        interval: 33
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            drift.phase = (drift.phase + 2 * Math.PI * (now - last) / drift.period) % (2 * Math.PI)
            last = now
        }
    }
}
