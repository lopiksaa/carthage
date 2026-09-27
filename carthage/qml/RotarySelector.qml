// A machined rotary selector with its positions printed beside it (the Hi-Fi skin's Sort).
// Turn it by clicking it (next position), scrolling on it, the arrow keys, or choose a label.
//   RotarySelector { options: [{ value, text }]; value: "recent"; onPicked: (v) => … }
import QtQuick
import Carthage

Item {
    id: rot

    property var options: []
    property var value
    property Item appRoot
    signal picked(var value)

    readonly property int index: Math.max(0, options.findIndex(o => o.value === value))
    readonly property real sweep: 120  // degrees from the first position to the last

    implicitWidth: knob.width + 12 + scale.implicitWidth
    implicitHeight: 48
    activeFocusOnTab: true
    Accessible.role: Accessible.Dial
    Accessible.name: "Sort: " + ((options[index] || {}).text || "")
    Keys.onRightPressed: turn(1)
    Keys.onUpPressed: turn(1)
    Keys.onLeftPressed: turn(-1)
    Keys.onDownPressed: turn(-1)

    function turn(d) {
        if (!options.length) return
        const n = (index + d + options.length) % options.length
        if (appRoot) appRoot.sound("half_click")
        picked(options[n].value)
    }

    // The knob: knurled rim, a dished face turned by the machine, an orange pointer.
    Item {
        id: knob
        width: 44
        height: 44
        anchors.verticalCenter: parent.verticalCenter
        Rectangle { // shadow under it
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: -3
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        Rectangle { // knurled rim
            id: rim
            anchors.fill: parent
            radius: width / 2
            color: "#b9bab6"
            border.width: 2
            border.color: "#6a6b67"
            Repeater {
                model: 36
                Rectangle {
                    required property int index
                    x: rim.width / 2 - 0.5
                    width: 1
                    height: 4
                    color: Qt.rgba(0, 0, 0, 0.35)
                    transform: Rotation { origin.x: 0.5; origin.y: rim.height / 2; angle: index * 10 }
                }
            }
        }
        Rectangle { // the face, turning to the chosen position
            anchors.fill: parent
            anchors.margins: 6
            radius: width / 2
            rotation: -rot.sweep / 2 + (rot.options.length > 1 ? rot.index * rot.sweep / (rot.options.length - 1) : 0)
            Behavior on rotation { SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.1 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f8f8f6" }
                GradientStop { position: 0.5; color: "#d4d5d1" }
                GradientStop { position: 1.0; color: "#a6a7a3" }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                width: 3
                height: 11
                radius: 1.5
                color: "#ff6a1a"
            }
        }
        Rectangle {
            visible: rot.activeFocus
            anchors.fill: parent
            anchors.margins: -4
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: rot.turn(1)
            onWheel: (w) => rot.turn(w.angleDelta.y < 0 ? 1 : -1)
        }
    }

    // The printed positions: a dot and a word each, lit orange where it points.
    Grid {
        id: scale
        anchors.left: knob.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        columns: 3
        rowSpacing: 5
        columnSpacing: 12
        Repeater {
            model: rot.options
            delegate: Row {
                required property var modelData
                required property int index
                spacing: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: index === rot.index ? "#ff6a1a" : "#5d5e5a"
                }
                Text {
                    text: String(modelData.short || modelData.text).toUpperCase()
                    color: index === rot.index ? "#1d1d1d" : "#5d5e5a"
                    font.family: "Barlow Condensed"
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    font.letterSpacing: 1.6
                    style: Text.Raised
                    styleColor: Qt.rgba(1, 1, 1, 0.7)
                }
                TapHandler { onTapped: { if (index !== rot.index) { if (rot.appRoot) rot.appRoot.sound("half_click"); rot.picked(modelData.value) } } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
