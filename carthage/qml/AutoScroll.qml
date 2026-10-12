// Middle-click scrolling, as in web browsers: a middle click drops an anchor and the view scrolls
// toward the pointer, faster the further it is; any click or Esc stops it. Pressing the middle
// button and dragging scrolls while it's held, and stops on release.
//   AutoScroll { flickable: myList }   (declared anywhere; it covers the flickable)
import QtQuick
import Carthage

Item {
    id: scroller

    property Flickable flickable
    property bool active: false
    property point anchorPt
    property point pointer
    property double pressedAt: 0
    readonly property real dead: 14  // around the anchor: no scrolling
    readonly property real dy: pointer.y - anchorPt.y

    function stop() { active = false }

    parent: flickable
    anchors.fill: parent
    z: 1000
    visible: !!flickable

    MouseArea {
        anchors.fill: parent
        acceptedButtons: scroller.active ? Qt.AllButtons : Qt.MiddleButton
        hoverEnabled: scroller.active
        cursorShape: scroller.active ? Qt.SizeVerCursor : Qt.ArrowCursor
        onPressed: (m) => {
            if (scroller.active) { scroller.stop(); return }
            const f = scroller.flickable
            if (!f || f.contentHeight + f.topMargin + f.bottomMargin <= f.height) { m.accepted = false; return }
            scroller.anchorPt = Qt.point(m.x, m.y)
            scroller.pointer = scroller.anchorPt
            scroller.pressedAt = Date.now()
            scroller.active = true
        }
        onPositionChanged: (m) => scroller.pointer = Qt.point(m.x, m.y)
        // Held and dragged: it ends with the button. A quick click: it stays until the next one.
        onReleased: (m) => {
            if (scroller.active && m.button === Qt.MiddleButton && Date.now() - scroller.pressedAt > 300
                    && Math.abs(scroller.dy) > scroller.dead) scroller.stop()
        }
        onWheel: (w) => { if (scroller.active) scroller.stop(); w.accepted = false }
    }
    Shortcut {
        enabled: scroller.active
        sequence: "Esc"
        onActivated: scroller.stop()
    }

    FrameAnimation {
        running: scroller.active
        onTriggered: {
            const f = scroller.flickable
            const d = Math.abs(scroller.dy) - scroller.dead
            if (!f || d <= 0) return
            const v = Math.sign(scroller.dy) * Math.pow(d, 1.3) * 2.2  // px per second
            const top = f.originY - f.topMargin
            const bottom = Math.max(top, f.originY + f.contentHeight + f.bottomMargin - f.height)
            f.contentY = Math.max(top, Math.min(bottom, f.contentY + v * frameTime))
        }
    }

    // The anchor: a small disc with up and down arrows where the click was.
    Rectangle {
        visible: scroller.active
        x: scroller.anchorPt.x - width / 2
        y: scroller.anchorPt.y - height / 2
        width: 30
        height: 30
        radius: 15
        color: Qt.rgba(0, 0, 0, 0.55)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.8)
        CIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3
            width: 10
            height: 10
            source: "go-up-symbolic"
            color: "white"
            opacity: scroller.dy < -scroller.dead ? 1 : 0.6
        }
        CIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 3
            width: 10
            height: 10
            source: "go-down-symbolic"
            color: "white"
            opacity: scroller.dy > scroller.dead ? 1 : 0.6
        }
    }
}
