// Library | Store as a rotary dial. Click a word or the knob, or use ← → (Space flips it).
import QtQuick
import Carthage

FocusScope {
    id: sw

    property string value: "library"
    signal picked(string value)

    readonly property var pal: Backend.theme.p
    readonly property bool dark: Backend.theme.dark
    readonly property bool store: value === "store"
    property real t: store ? 1 : 0
    Behavior on t { SpringAnimation { spring: 5; damping: 0.42; epsilon: 0.004 } }

    function pick(v) { if (v !== value) picked(v) }
    // Where the Library side is (cartridges fly into it from the store).
    function libraryPoint(item) {
        return libraryLabel.mapToItem(item, libraryLabel.width / 2, libraryLabel.height / 2)
    }

    implicitWidth: 176
    implicitHeight: 38
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTabList
    Accessible.name: "Library or Store"
    Keys.onLeftPressed: pick("library")
    Keys.onRightPressed: pick("store")
    Keys.onSpacePressed: pick(store ? "library" : "store")

    component Engraved: Text {
        id: word
        property bool on: false
        property string choice
        color: on ? sw.pal.dockText : sw.pal.dockTextDim
        font.family: "Nunito"
        font.weight: Font.Black
        font.pixelSize: 11
        font.letterSpacing: 1.6
        style: Text.Raised
        styleColor: sw.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.8)
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.pick(word.choice)
        }
    }

    Rectangle {
        visible: sw.activeFocus
        anchors.fill: parent
        anchors.margins: -3
        radius: 13
        color: "transparent"
        border.width: 2
        border.color: Ui.focusColor
    }

    Engraved {
        id: libraryLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "LIBRARY"
        choice: "library"
        on: !sw.store
    }
    Engraved {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "STORE"
        choice: "store"
        on: sw.store
    }
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real a: (index === 0 ? -50 : 50) * Math.PI / 180
            x: knob.x + knob.width / 2 + Math.sin(a) * 21 - 1
            y: knob.y + knob.height / 2 - Math.cos(a) * 21 - 1
            width: 3
            height: 3
            radius: 1.5
            color: (index === 0) === !sw.store ? Backend.theme.led.green : sw.pal.dockTextDim
        }
    }
    Rectangle {
        id: knob
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 16
        color: Qt.darker(sw.pal.dockBottom, sw.dark ? 1.45 : 1.12)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, sw.dark ? 0.5 : 0.18)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, sw.dark ? 0.35 : 0.1) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            rotation: -50 + 100 * sw.t
            gradient: Gradient {
                GradientStop { position: 0.0; color: sw.pal.dockTop }
                GradientStop { position: 1.0; color: Qt.darker(sw.pal.dockBottom, 1.1) }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, sw.dark ? 0.55 : 0.2)
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    x: parent.width / 2 - 0.5
                    width: 1
                    height: 3
                    color: Qt.rgba(0, 0, 0, sw.dark ? 0.45 : 0.15)
                    transform: Rotation { origin.x: 0.5; origin.y: parent.height / 2; angle: index * 22.5 }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: 3
                height: 8
                radius: 1.5
                color: Backend.theme.accent.accent
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.pick(sw.store ? "library" : "store")
        }
    }
}
