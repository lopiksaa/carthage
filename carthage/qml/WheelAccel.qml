// Wheel scrolling that speeds up while the wheel keeps turning; touchpads scroll natively.
// A wheel is told by what it sends, not by the device type: under Wayland, Qt reports a mouse
// wheel as a "touchpad" (whole 120-unit notches, no pixel distance), and a real touchpad sends
// pixel distances.
//   WheelAccel { flickable: myList; step: 120 }
import QtQuick
import Carthage

WheelHandler {
    id: wa

    property Flickable flickable
    property real step: 110
    property bool horizontal: false
    property real boost: 1
    property double last: 0
    property real dest: 0
    // The wheel turned up while the view was already at its top (e.g. leave a gallery).
    signal pastStart()

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    target: null
    onWheel: (event) => {
        if (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0) {
            event.accepted = false  // a touchpad: the view's own kinetic scrolling
            return
        }
        const f = wa.flickable
        if (!f) return
        const now = Date.now()
        wa.boost = now - wa.last < 140 ? Math.min(6, wa.boost * 1.3) : 1
        wa.last = now
        const notches = event.angleDelta.y / 120
        if (wa.horizontal) {
            const from = glide.running ? wa.dest : f.contentX
            const lo = f.originX - f.leftMargin
            const hi = Math.max(lo, f.contentWidth + f.originX + f.rightMargin - f.width)
            wa.dest = Math.max(lo, Math.min(hi, from - notches * wa.step * wa.boost))
            glide.property = "contentX"
        } else {
            const from = glide.running ? wa.dest : f.contentY
            const lo = f.originY - f.topMargin
            if (notches > 0 && from <= lo + 0.5) wa.pastStart()
            const hi = Math.max(lo, f.contentHeight + f.originY + f.bottomMargin - f.height)
            wa.dest = Math.max(lo, Math.min(hi, from - notches * wa.step * wa.boost))
            glide.property = "contentY"
        }
        glide.to = wa.dest
        glide.duration = 180
        glide.restart()
        event.accepted = true
    }

    // Glide as if the wheel had asked for it, so a wheel turned meanwhile carries on instead of
    // fighting it.
    function glideTo(value, ms) {
        if (!wa.flickable) return
        wa.dest = value
        glide.property = wa.horizontal ? "contentX" : "contentY"
        glide.to = value
        glide.duration = ms
        glide.restart()
    }

    readonly property bool gliding: glide.running
    property NumberAnimation glide: NumberAnimation {
        target: wa.flickable
        duration: 180 * Backend.motion
        easing.type: Easing.OutCubic
    }
}
