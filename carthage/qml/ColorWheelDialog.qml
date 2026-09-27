// Custom plastic colors: a hue ring, five tones, and for cartridges, colors that go with the
// hardware (colors.py).
import QtQuick
import Carthage
import QtQuick.Shapes

CDialog {
    id: dlg

    property string target: "hardware" // or "card"
    property real hue: 250
    property int tone: 2
    property string chosen: ""
    readonly property var toneList: Backend.theme.tones(hue)
    readonly property string hardwarePlastic: Backend.theme.plasticOf(Backend.settings.hardware)
    readonly property var recommended: target === "card" ? Backend.theme.harmonies(hardwarePlastic) : []
    readonly property var ringStops: {
        const out = []
        for (let h = 0; h <= 360; h += 30) out.push(Backend.theme.tones(h % 360)[2].color)
        return out
    }
    readonly property real ringAngle: 90 // where hue 0 sits (degrees, counter-clockwise from 3 o'clock)

    function openFor(t) {
        target = t
        const current = t === "card" ? Backend.settings.cardColor : Backend.settings.hardware
        const plastic = Backend.theme.plasticOf(current === "same" ? Backend.settings.hardware : current)
        hue = plastic ? Backend.theme.hueOf(plastic) : 250
        tone = 2
        chosen = current.startsWith("c_") ? plastic : ""
        open()
    }
    function apply() {
        const c = chosen || toneList[tone].color
        const v = Backend.theme.customValue(c)
        if (target === "card") Backend.settings.cardColor = v
        else Backend.settings.hardware = v
        close()
    }
    readonly property string preview: chosen || (toneList.length ? toneList[tone].color : "#888888")

    maxWidth: 440

    contentItem: Column {
        spacing: Ui.gapL
        Accessible.role: Accessible.Dialog
        Accessible.name: title.text

        Text {
            id: title
            text: dlg.target === "card" ? "Cartridge Color" : "Hardware Color"
            color: dlg.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }

        Item {
            id: wheel
            anchors.horizontalCenter: parent.horizontalCenter
            width: 208
            height: 208
            readonly property real outer: width / 2
            readonly property real inner: outer - 30

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: ConicalGradient {
                        centerX: wheel.outer
                        centerY: wheel.outer
                        angle: dlg.ringAngle
                        GradientStop { position: 0 / 12; color: dlg.ringStops[0] }
                        GradientStop { position: 1 / 12; color: dlg.ringStops[1] }
                        GradientStop { position: 2 / 12; color: dlg.ringStops[2] }
                        GradientStop { position: 3 / 12; color: dlg.ringStops[3] }
                        GradientStop { position: 4 / 12; color: dlg.ringStops[4] }
                        GradientStop { position: 5 / 12; color: dlg.ringStops[5] }
                        GradientStop { position: 6 / 12; color: dlg.ringStops[6] }
                        GradientStop { position: 7 / 12; color: dlg.ringStops[7] }
                        GradientStop { position: 8 / 12; color: dlg.ringStops[8] }
                        GradientStop { position: 9 / 12; color: dlg.ringStops[9] }
                        GradientStop { position: 10 / 12; color: dlg.ringStops[10] }
                        GradientStop { position: 11 / 12; color: dlg.ringStops[11] }
                        GradientStop { position: 12 / 12; color: dlg.ringStops[12] }
                    }
                    PathAngleArc { centerX: wheel.outer; centerY: wheel.outer; radiusX: wheel.outer; radiusY: wheel.outer; startAngle: 0; sweepAngle: 360 }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: wheel.inner * 2
                height: width
                radius: width / 2
                color: dlg.pal.panel
            }
            Rectangle {
                anchors.centerIn: parent
                width: wheel.inner * 2 - 36
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(dlg.preview, 1.08) }
                    GradientStop { position: 1; color: Qt.darker(dlg.preview, 1.15) }
                }
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.25)
            }
            Rectangle {
                readonly property real a: (dlg.hue + dlg.ringAngle) * Math.PI / 180
                readonly property real r: (wheel.outer + wheel.inner) / 2
                x: wheel.outer + r * Math.cos(a) - width / 2
                y: wheel.outer - r * Math.sin(a) - height / 2
                width: 24
                height: 24
                radius: 12
                color: dlg.toneList.length ? dlg.toneList[2].color : "white"
                border.width: 3
                border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                function pick(mx, my) {
                    const dx = mx - wheel.outer, dy = my - wheel.outer
                    if (Math.hypot(dx, dy) < wheel.inner - 12) return
                    const deg = Math.atan2(-dy, dx) * 180 / Math.PI
                    dlg.hue = ((deg - dlg.ringAngle) % 360 + 360) % 360
                    dlg.chosen = ""
                }
                onPressed: (m) => pick(m.x, m.y)
                onPositionChanged: (m) => { if (pressed) pick(m.x, m.y) }
            }
            Accessible.role: Accessible.Dial
            Accessible.name: "Hue " + Math.round(dlg.hue) + " degrees"
            Keys.onLeftPressed: { dlg.hue = (dlg.hue + 350) % 360; dlg.chosen = "" }
            Keys.onRightPressed: { dlg.hue = (dlg.hue + 10) % 360; dlg.chosen = "" }
            activeFocusOnTab: true
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Ui.gapM
            Repeater {
                model: dlg.toneList
                delegate: Column {
                    required property var modelData
                    required property int index
                    spacing: Ui.gapXS
                    ColorChip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: modelData.name
                        plastic: modelData.color
                        selected: !dlg.chosen && dlg.tone === index
                        onPicked: { dlg.tone = index; dlg.chosen = "" }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name
                        color: dlg.pal.panelTextDim
                        font.family: "Nunito"
                        font.pixelSize: Ui.textCaption
                    }
                }
            }
        }

        Column {
            visible: dlg.recommended.length > 0
            width: parent.width
            spacing: Ui.gapS
            Text {
                text: "Recommended with your hardware"
                color: dlg.pal.panelText
                font.family: "Nunito"
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
            }
            Repeater {
                model: {
                    const groups = []
                    for (const r of dlg.recommended) {
                        let g = groups.find(x => x.name === r.group)
                        if (!g) { g = { name: r.group, items: [] }; groups.push(g) }
                        g.items.push(r)
                    }
                    return groups
                }
                delegate: Row {
                    required property var modelData
                    spacing: Ui.gapS
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        text: modelData.name
                        color: dlg.pal.panelTextDim
                        font.family: "Nunito"
                        font.pixelSize: Ui.textCaption
                    }
                    Repeater {
                        model: modelData.items
                        delegate: ColorChip {
                            required property var modelData
                            label: modelData.name
                            plastic: modelData.color
                            selected: dlg.chosen === modelData.color
                            onPicked: dlg.chosen = modelData.color
                        }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            CButton {
                text: "Cancel"
                onClicked: dlg.close()
            }
            CButton {
                kind: "primary"
                text: "Use Color"
                onClicked: dlg.apply()
            }
        }
    }
}
