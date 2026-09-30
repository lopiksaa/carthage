// A custom plastic color: a saturation/brightness square, a hue slider and a hex field.
//   colorPicker.openFor("hardware")  // or "card"
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: dlg

    property string target: "hardware" // or "card"
    property real hue: 0.6   // 0–1
    property real sat: 0.5   // 0–1, left to right
    property real val: 0.8   // 0–1, bottom to top
    readonly property color picked: Qt.hsva(hue, sat, val, 1)
    readonly property string pickedHex: "#" + [picked.r, picked.g, picked.b]
        .map(c => ("0" + Math.round(c * 255).toString(16)).slice(-2)).join("")

    function setFrom(hex) {
        const c = Qt.color(hex)
        // A grey has no hue: keep the slider where it was.
        if (c.hsvHue >= 0) hue = c.hsvHue
        sat = c.hsvSaturation
        val = c.hsvValue
    }
    function openFor(t) {
        target = t
        const current = t === "card" ? Backend.settings.cardColor : Backend.settings.hardware
        const plastic = Backend.theme.plasticOf(current === "same" ? Backend.settings.hardware : current)
        setFrom(plastic || "#5b6ee1")
        hexField.text = pickedHex
        open()
    }
    function apply() {
        const v = Backend.theme.customValue(pickedHex)
        if (target === "card") Backend.settings.cardColor = v
        else Backend.settings.hardware = v
        close()
    }
    onPickedHexChanged: if (!hexField.activeFocus) hexField.text = pickedHex

    maxWidth: 400

    contentItem: Column {
        spacing: Ui.gapL
        Accessible.role: Accessible.Dialog
        Accessible.name: title.text

        Text {
            id: title
            text: dlg.target === "card" ? "Cartridge Color" : "Hardware Color"
            color: dlg.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }

        // Saturation (left → right) and brightness (bottom → top) for the current hue.
        Item {
            id: square
            width: parent.width
            height: 190
            activeFocusOnTab: true
            Accessible.role: Accessible.Slider
            Accessible.name: "Color saturation and brightness"
            Keys.onLeftPressed: dlg.sat = Math.max(0, dlg.sat - 0.02)
            Keys.onRightPressed: dlg.sat = Math.min(1, dlg.sat + 0.02)
            Keys.onUpPressed: dlg.val = Math.min(1, dlg.val + 0.02)
            Keys.onDownPressed: dlg.val = Math.max(0, dlg.val - 0.02)
            Rectangle {
                anchors.fill: parent
                radius: Ui.radiusSmall
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffff" }
                    GradientStop { position: 1; color: Qt.hsva(dlg.hue, 1, 1, 1) }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: Ui.radiusSmall
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "#000000" }
                }
                border.width: square.activeFocus ? 2 : 1
                border.color: square.activeFocus ? Ui.focusColor : Qt.rgba(0, 0, 0, 0.3)
            }
            Rectangle { // the marker
                x: dlg.sat * square.width - width / 2
                y: (1 - dlg.val) * square.height - height / 2
                width: 18
                height: 18
                radius: 9
                color: dlg.picked
                border.width: 3
                border.color: "#ffffff"
                Rectangle { anchors.fill: parent; anchors.margins: -1; radius: width / 2; color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.4) }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                function pick(m) {
                    square.forceActiveFocus()
                    dlg.sat = Math.max(0, Math.min(1, m.x / width))
                    dlg.val = Math.max(0, Math.min(1, 1 - m.y / height))
                }
                onPressed: (m) => pick(m)
                onPositionChanged: (m) => { if (pressed) pick(m) }
            }
        }

        // Hue.
        Item {
            id: hueBar
            width: parent.width
            height: 18
            activeFocusOnTab: true
            Accessible.role: Accessible.Slider
            Accessible.name: "Hue"
            Keys.onLeftPressed: dlg.hue = (dlg.hue + 359 / 360) % 1
            Keys.onRightPressed: dlg.hue = (dlg.hue + 1 / 360) % 1
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                border.width: hueBar.activeFocus ? 2 : 0
                border.color: Ui.focusColor
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0 / 6; color: "#ff0000" }
                    GradientStop { position: 1 / 6; color: "#ffff00" }
                    GradientStop { position: 2 / 6; color: "#00ff00" }
                    GradientStop { position: 3 / 6; color: "#00ffff" }
                    GradientStop { position: 4 / 6; color: "#0000ff" }
                    GradientStop { position: 5 / 6; color: "#ff00ff" }
                    GradientStop { position: 6 / 6; color: "#ff0000" }
                }
            }
            Rectangle { // the marker
                x: dlg.hue * hueBar.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: Qt.hsva(dlg.hue, 1, 1, 1)
                border.width: 3
                border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                function pick(m) {
                    hueBar.forceActiveFocus()
                    dlg.hue = Math.max(0, Math.min(0.9999, (m.x - 6) / hueBar.width))
                }
                onPressed: (m) => pick(m)
                onPositionChanged: (m) => { if (pressed) pick(m) }
            }
        }

        // Preview and hex.
        Row {
            spacing: Ui.gapM
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Ui.radiusSmall
                color: dlg.picked
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
            }
            QQC2.TextField {
                id: hexField
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                height: Ui.controlHeight
                leftPadding: 12
                rightPadding: 12
                color: dlg.pal.panelText
                font.family: "DM Mono"
                font.pixelSize: Ui.textBody
                selectByMouse: true
                background: Rectangle {
                    radius: Ui.radiusMedium
                    color: dlg.pal.panelHover
                    border.width: hexField.activeFocus ? 2 : 1
                    border.color: hexField.activeFocus ? Backend.theme.accent.accent : dlg.pal.panelBorder
                }
                Accessible.name: "Hex color"
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                onTextEdited: {
                    const t = text.startsWith("#") ? text : "#" + text
                    if (/^#[0-9a-fA-F]{6}$/.test(t)) dlg.setFrom(t)
                }
                onEditingFinished: text = dlg.pickedHex
                Keys.onReturnPressed: dlg.apply()
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
