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

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(seg.pal.panelHover, 0.9)
        border.width: 1
        border.color: seg.pal.panelBorder
    }
    Rectangle { // thumb
        visible: seg.current >= 0
        x: 3 + seg.current * seg.cellW
        y: 3
        width: seg.cellW - 6
        height: parent.height - 6
        radius: height / 2
        color: Backend.theme.accent.accent
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
                    color: opt.selected ? Backend.theme.accent.accentText : seg.pal.panelText
                    font.family: "Nunito"
                    font.weight: opt.selected ? Font.Black : Font.Bold
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
