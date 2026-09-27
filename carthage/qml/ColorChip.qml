// A color chip for the hardware and cartridge colors. With no color it shows "=" (same as the
// hardware).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Shapes

Item {
    id: chip

    property string label
    property color plastic: "transparent"
    property bool selected: false
    property bool rainbow: false // "pick your own color" (opens the color wheel)
    readonly property bool plain: plastic.a === 0
    signal picked()

    property real size: 30
    width: size
    height: size
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: label
    Accessible.checked: selected
    Keys.onSpacePressed: picked()
    Keys.onReturnPressed: picked()

    readonly property real radius: Math.round(size * 0.3)

    Item {
        anchors.fill: parent
        scale: hover.hovered ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }

        Shape {
            visible: chip.rainbow
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: ConicalGradient {
                    centerX: chip.width / 2
                    centerY: chip.height / 2
                    GradientStop { position: 0.00; color: "#e0565b" }
                    GradientStop { position: 0.17; color: "#e0a64f" }
                    GradientStop { position: 0.33; color: "#b8cf4f" }
                    GradientStop { position: 0.50; color: "#4fc2a0" }
                    GradientStop { position: 0.67; color: "#4f8fe0" }
                    GradientStop { position: 0.83; color: "#9a63d6" }
                    GradientStop { position: 1.00; color: "#e0565b" }
                }
                PathRectangle { x: 0; y: 0; width: chip.width; height: chip.height; radius: chip.radius }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: chip.radius
            color: "transparent"
            gradient: chip.plain ? null : plasticGradient
            Gradient {
                id: plasticGradient
                GradientStop { position: 0.0; color: Qt.lighter(chip.plastic, 1.08) }
                GradientStop { position: 1.0; color: Qt.darker(chip.plastic, 1.15) }
            }
            border.width: chip.selected ? 3 : 1
            border.color: chip.selected ? Backend.theme.accent.accent
                        : chip.plain && !chip.rainbow ? Backend.theme.p.panelTextDim : Qt.rgba(0, 0, 0, 0.25)
            Text {
                visible: chip.plain && !chip.rainbow
                anchors.centerIn: parent
                text: "="
                color: Backend.theme.p.panelText
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Math.round(chip.size * 0.55)
            }
        }
    }
    Rectangle {
        visible: chip.activeFocus
        anchors.fill: parent
        anchors.margins: -4
        radius: chip.radius + 4
        color: "transparent"
        border.width: 2
        border.color: Ui.focusColor
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.picked() }
    QQC2.ToolTip.visible: hover.hovered
    QQC2.ToolTip.text: label
    QQC2.ToolTip.delay: 300
}
