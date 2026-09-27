// A row of latching tape-deck keys (Hi-Fi's Show).
//   TapeKeys { options: [{ value, text }]; value: "all"; onPicked: (v) => … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: keys

    property var options: []
    property var value
    property int maxKeys: 6
    property Item appRoot
    signal picked(var value)

    readonly property var shown: options.length > maxKeys ? options.slice(0, maxKeys - 1) : options
    readonly property var extra: options.length > maxKeys ? options.slice(maxKeys - 1) : []
    readonly property bool extraOn: extra.some(o => o.value === value)

    implicitWidth: well.width
    implicitHeight: 42
    Accessible.role: Accessible.Grouping

    function choose(v) {
        if (v === value) { if (appRoot) appRoot.sound("half_click"); return }
        if (appRoot) appRoot.sound("key")
        picked(v)
    }

    Rectangle {
        id: well
        width: row.width + 12
        height: parent.height
        radius: 5
        color: "#1d1d1d"
        border.width: 1
        border.color: "#000000"
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.55)
            z: -1
        }
    }

    component TapeKey: Item {
        id: k
        property string label
        property bool latched: false
        signal pressed_()
        width: Math.max(44, txt.implicitWidth + 22)
        height: 34
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: label
        Accessible.checked: latched
        Keys.onReturnPressed: pressed_()
        Keys.onSpacePressed: pressed_()
        readonly property bool held: tap.pressed
        readonly property real travel: held ? 6 : latched ? 5 : 0
        Rectangle { // the key's front edge, visible while it's up
            anchors.fill: parent
            anchors.topMargin: 6
            radius: 4
            color: "#0a0a0a"
        }
        Rectangle {
            id: cap
            width: parent.width
            height: parent.height - 6
            y: k.travel
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3a3a3a" }
                GradientStop { position: 0.7; color: "#262626" }
                GradientStop { position: 1.0; color: "#1c1c1c" }
            }
            border.width: 1
            border.color: "#000000"
            Behavior on y { NumberAnimation { duration: 60 * Backend.motion } }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                y: 4
                height: 3
                radius: 1.5
                color: k.latched ? "#ff6a1a" : "#555555"
            }
            Text {
                id: txt
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 3
                text: k.label
                color: "#e9e6e0"
                font.family: "Barlow Condensed"
                font.weight: Font.Bold
                font.pixelSize: 12
                font.letterSpacing: 1.6
            }
        }
        Rectangle {
            visible: k.activeFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: 7
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: k.pressed_() }
    }

    Row {
        id: row
        x: 6
        y: 5
        spacing: 4
        Repeater {
            model: keys.shown
            delegate: TapeKey {
                required property var modelData
                label: String(modelData.short || modelData.text).toUpperCase()
                latched: modelData.value === keys.value
                onPressed_: keys.choose(modelData.value)
            }
        }
        TapeKey {
            id: more
            visible: keys.extra.length > 0
            label: keys.extraOn ? String((keys.extra.find(o => o.value === keys.value) || {}).text || "MORE").toUpperCase() : "MORE"
            latched: keys.extraOn
            onPressed_: { if (keys.appRoot) keys.appRoot.sound("key"); menu.popup(more, 0, more.height + 6) }
        }
    }
    CMenu {
        id: menu
        Instantiator {
            model: keys.extra
            delegate: QQC2.Action {
                required property var modelData
                text: modelData.text
                checkable: true
                checked: keys.value === modelData.value
                onTriggered: keys.picked(modelData.value)
            }
            onObjectAdded: (i, a) => menu.insertAction(i, a)
            onObjectRemoved: (i, a) => menu.removeAction(a)
        }
    }
}
