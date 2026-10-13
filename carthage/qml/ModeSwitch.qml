// Library | Store as a rotary dial. Click a word or the knob, or use ← → (Space flips it).
import QtQuick
import QtQuick.Shapes
import Carthage

FocusScope {
    id: sw

    property string value: "library"
    signal libraryHome()  // Library double-clicked: back to All Games
    signal picked(string value)

    readonly property var pal: Backend.theme.p
    readonly property bool dark: Backend.theme.dark
    readonly property bool store: value === "store"
    property real t: store ? 1 : 0
    Behavior on t { SpringAnimation { spring: 5; damping: 0.42; epsilon: 0.004 } }

    function pick(v) { if (v !== value) picked(v) }
    // Where the Library side is (cartridges fly into it from the store).
    function libraryPoint(item) {
        const l = Backend.theme.glassy ? segLibrary : libraryLabel
        return l.mapToItem(item, l.width / 2, l.height / 2)
    }

    implicitWidth: Backend.theme.glassy ? pill.width : 176
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
        font.family: Ui.fontLabels
        font.weight: Font.Black
        font.pixelSize: 11
        font.letterSpacing: 1.6
        style: Backend.theme.glassy ? Text.Normal : Text.Raised
        styleColor: sw.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.8)
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.pick(word.choice)
            onDoubleClicked: if (word.choice === "library") sw.libraryHome()
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

    // Glass: LIBRARY | STORE in one glass pill; a lit thumb slides under the one you're on
    // (Sam's pick in the Glass Lab, replacing the glass knob).
    Rectangle {
        id: pill
        visible: Backend.theme.glassy
        readonly property var g: Backend.theme.glass
        anchors.verticalCenter: parent.verticalCenter
        width: segRow.width + 8
        height: 36
        radius: 18
        color: g.field
        border.width: 1
        border.color: g.ring
        GlassSurface {  // the thumb
            x: 4 + sw.t * (segStore.x - segLibrary.x)
            y: 4
            width: segLibrary.width + sw.t * (segStore.width - segLibrary.width)
            height: parent.height - 8
            radius: height / 2
            tint: Backend.theme.dark ? Qt.rgba(1, 1, 1, 0.14) : pill.g.tint  // lit, on dark glass too
            sheen: Qt.alpha(pill.g.sheen, Math.min(1, Qt.color(pill.g.sheen).a * 2 + 0.06))
            shadowY: 3
            shadowBlur: 8
            shadowSpread: -2
        }
        Row {
            id: segRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [["library", "LIBRARY"], ["store", "STORE"]]
                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool on: sw.value === modelData[0]
                    width: segLabel.implicitWidth + 32
                    height: 28
                    Component.onCompleted: if (index === 0) sw.segLibraryRef = seg; else sw.segStoreRef = seg
                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        text: seg.modelData[1]
                        color: seg.on ? pill.g.text : pill.g.text2
                        font.family: Ui.fontLabels
                        font.weight: Font.Black
                        font.pixelSize: 11
                        font.letterSpacing: 1.6
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sw.pick(seg.modelData[0])
                        onDoubleClicked: if (seg.modelData[0] === "library") sw.libraryHome()
                    }
                }
            }
        }
    }
    property Item segLibraryRef: null
    property Item segStoreRef: null
    readonly property Item segLibrary: segLibraryRef || pill
    readonly property Item segStore: segStoreRef || pill

    Engraved {
        id: libraryLabel
        visible: !Backend.theme.glassy
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "LIBRARY"
        choice: "library"
        on: !sw.store
    }
    Engraved {
        visible: !Backend.theme.glassy
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
            visible: !Backend.theme.glassy
            x: knob.x + knob.width / 2 + Math.sin(a) * 21 - 1
            y: knob.y + knob.height / 2 - Math.cos(a) * 21 - 1
            width: 3
            height: 3
            radius: 1.5
            color: (index === 0) === !sw.store ? Backend.theme.led.green : sw.pal.dockTextDim
        }
    }
    // Glass: a glass sphere with a highlight up and left, an accent tick (−42° Library, +42°
    // Store) and two faint detents (design handoff).
    Item {
        id: glassKnob
        visible: false  // (replaced by the pill; kept until the plastic dial lands)
        anchors.centerIn: parent
        width: 34
        height: 34
        readonly property var g: Backend.theme.glass
        Repeater {
            model: 2
            Rectangle {
                required property int index
                readonly property real a: (index === 0 ? -42 : 42) * Math.PI / 180
                x: glassKnob.width / 2 + Math.sin(a) * 22 - 2
                y: glassKnob.height / 2 - Math.cos(a) * 22 - 2
                width: 4
                height: 4
                radius: 2
                color: glassKnob.g.ring
            }
        }
        GlassSurface {
            anchors.fill: parent
            radius: width / 2
            sheen: "transparent"
            edge: "transparent"
            shadowY: 6
            shadowBlur: 14
            shadowSpread: -4
        }
        Shape {  // the highlight: radial, from up and left (CSS: circle at 34% 28%)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 34 * 0.34; centerY: 34 * 0.28; centerRadius: 33.2
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.8) }
                    GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.14) }
                    GradientStop { position: 0.70; color: Qt.rgba(1, 1, 1, 0.05) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
                }
                PathAngleArc { centerX: 17; centerY: 17; radiusX: 17; radiusY: 17; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle {  // the tick
            x: 16
            y: 4
            width: 2
            height: 9
            radius: 1
            color: glassKnob.g.accent
            transform: Rotation { origin.x: 1; origin.y: 13; angle: -42 + 84 * sw.t }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.pick(sw.store ? "library" : "store")
        }
    }
    Rectangle {
        id: knob
        visible: !Backend.theme.glassy
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
