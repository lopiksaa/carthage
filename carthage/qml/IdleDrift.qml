// A faint, slow drift so a held cartridge doesn't look pasted on. Off at animation speed
// "Instant".
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

    property real amount: active && motion > 0 ? 1 : 0
    Behavior on amount { NumberAnimation { duration: drift.fadeDuration; easing.type: Easing.InOutSine } }
    property real phase: 0
    NumberAnimation on phase {
        running: drift.amount > 0
        from: 0
        to: 2 * Math.PI
        duration: drift.period
        loops: Animation.Infinite
    }
}
