// A segmented choice (pill with sliding thumb), e.g. All / Installed / Not Installed.
import QtQuick
import Carthage

Item {
    id: seg

    property var options: [] // [{ value, text }]
    property var value
    signal picked(var value)

    readonly property var pal: Backend.theme.p
    readonly property int current: options.findIndex(o => o.value === value)
    readonly property real cellW: options.length ? width / options.length : 0

    implicitHeight: Ui.controlHeight
    Accessible.role: Accessible.PageTabList

    // A quiet track with the chosen option raised in it (the same as the search filters).
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Backend.theme.dark ? Qt.darker(seg.pal.panel, 1.3) : Qt.darker(seg.pal.panelHover, 1.05)
        border.width: 1
        border.color: seg.pal.panelBorder
    }
    Rectangle {
        visible: seg.current >= 0
        x: 3 + seg.current * seg.cellW
        y: 3
        width: seg.cellW - 6
        height: parent.height - 6
        radius: height / 2
        color: Backend.theme.dark ? Qt.lighter(seg.pal.panelHover, 1.35) : seg.pal.panel
        border.width: 1
        border.color: seg.pal.panelBorder
        Rectangle {  // its lit top edge
            x: parent.radius
            width: parent.width - 2 * parent.radius
            y: 1
            height: 1
            color: Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.08 : 0.9)
        }
        Behavior on x {
            NumberAnimation { duration: (200 * Backend.motion); easing.type: Easing.OutCubic }
        }
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: seg.options
            delegate: Item {
                id: opt
                required property var modelData
                required property int index
                readonly property bool selected: index === seg.current
                width: seg.cellW
                height: seg.height
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text
                Accessible.selected: selected
                Keys.onSpacePressed: seg.picked(modelData.value)
                Keys.onReturnPressed: seg.picked(modelData.value)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: opt.modelData.text
                    color: opt.selected ? seg.pal.panelText : seg.pal.panelTextDim
                    font.family: Ui.fontButtons
                    font.weight: opt.selected ? Font.Black : Font.DemiBold
                    font.pixelSize: Ui.textBody
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: opt.activeFocus
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: height / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Ui.focusColor
                }
                TapHandler {
                    onTapped: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
