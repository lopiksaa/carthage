// A compact choice that opens a menu: "Sort  Recent ▾". For a short list of options where a
// segmented control would take too much room (the library bar).
//   CDropdown { label: "Sort"; value: "recent"; options: [{ value, text }]; onPicked: (v) => … }
// A long list (Genre) sets chipColumns: it opens a panel of chips in that many columns instead
// of a menu, so it never has to scroll.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CButton {
    id: dd

    property string label
    property var value
    property var options: [] // [{ value, text }]
    property int chipColumns: 0 // 0: a menu; more: a panel of chips in this many columns
    property bool compact: false // just the value (a narrow bar); the label stays in Accessible.name
    property string compactIcon     // shown instead of the label when compact, so two "All"s differ
    signal picked(var value)

    readonly property string currentText: (options.find(o => o.value === value) || options[0] || {}).text || ""

    kind: "plain"
    implicitWidth: row_.implicitWidth + 2 * Ui.gapM
    Accessible.name: label + ": " + currentText
    onClicked: dd.chipColumns > 0 ? chipPanel.open() : menu.popup(dd, 0, dd.height + 6)

    contentItem: Item {
        implicitWidth: row_.implicitWidth
        implicitHeight: row_.implicitHeight
        Row {
            id: row_
            anchors.centerIn: parent
            spacing: 6
            CIcon {
                visible: dd.compact && dd.compactIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: dd.compactIcon
                color: dd.isKey ? Qt.alpha(dd.fg, 0.62) : dd.pal.panelTextDim
            }
            Text {
                visible: !dd.compact
                anchors.verticalCenter: parent.verticalCenter
                text: dd.label
                color: dd.isKey ? Qt.alpha(dd.fg, 0.62) : dd.pal.panelTextDim
                font.family: Ui.fontButtons
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dd.currentText
                color: dd.fg
                font.family: Ui.fontButtons
                font.weight: Font.Black
                font.pixelSize: Ui.textBody
            }
            CIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: "go-down-symbolic"
                isMask: true
                color: dd.isKey ? Qt.alpha(dd.fg, 0.62) : dd.pal.panelTextDim
            }
        }
    }

    // The chip panel (chipColumns > 0).
    QQC2.Popup {
        id: chipPanel
        x: dd.width - width  // lined up with the button's right edge
        y: dd.height + 6
        padding: Ui.gapM
        modal: true
        dim: false
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        // Counted like a menu while open (input behind is blocked), given back even if destroyed.
        property bool counted: false
        function release() {
            if (!counted) return
            counted = false
            Ui.openMenus = Math.max(0, Ui.openMenus - 1)
        }
        onOpened: {
            if (!counted) { counted = true; Ui.openMenus++ }
            const i = dd.options.findIndex(o => o.value === dd.value)
            const chip = chips.itemAt(Math.max(0, i))
            if (chip) chip.forceActiveFocus()
        }
        onClosed: release()
        Component.onDestruction: release()
        background: PanelBackground {}
        contentItem: Grid {
            id: grid
            columns: Math.max(1, dd.chipColumns)
            spacing: Ui.gapXS
            // Every chip as wide as the widest, so the columns line up.
            readonly property real chipW: {
                let w = 0
                for (let i = 0; i < chips.count; i++) if (chips.itemAt(i)) w = Math.max(w, chips.itemAt(i).implicitWidth)
                return w
            }
            Accessible.role: Accessible.List
            Accessible.name: dd.label
            Repeater {
                id: chips
                model: dd.options
                delegate: QQC2.AbstractButton {
                    id: chip
                    required property var modelData
                    readonly property bool chosen: dd.value === modelData.value
                    implicitWidth: chipText.implicitWidth + 2 * Ui.gapM
                    width: grid.chipW
                    height: 32
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.text
                    Accessible.checked: chosen
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    onClicked: { chipPanel.close(); dd.picked(modelData.value) }
                    background: Rectangle {
                        radius: Ui.radiusSmall
                        color: chip.chosen ? Backend.theme.accent.accent
                             : chip.hovered ? dd.pal.panelHover : "transparent"
                        border.width: chip.visualFocus ? 2 : 0
                        border.color: Ui.focusColor
                    }
                    contentItem: Text {
                        id: chipText
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Ui.gapM
                        rightPadding: Ui.gapM
                        text: chip.modelData.text
                        color: chip.chosen ? Backend.theme.accent.accentText : dd.pal.panelText
                        font.family: Ui.fontText
                        font.weight: chip.chosen ? Font.Bold : Font.DemiBold
                        font.pixelSize: Ui.textBody
                    }
                }
            }
        }
    }

    CMenu {
        id: menu
        Instantiator {
            model: dd.options
            delegate: QQC2.Action {
                required property var modelData
                text: modelData.text
                checkable: true
                checked: dd.value === modelData.value
                onTriggered: dd.picked(modelData.value)
            }
            onObjectAdded: (i, a) => menu.insertAction(i, a)
            onObjectRemoved: (i, a) => menu.removeAction(a)
        }
    }
}
