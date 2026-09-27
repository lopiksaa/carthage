// A compact choice that opens a menu: "Sort  Recent ▾". For a short list of options where a
// segmented control would take too much room (the library bar).
//   CDropdown { label: "Sort"; value: "recent"; options: [{ value, text }]; onPicked: (v) => … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CButton {
    id: dd

    property string label
    property var value
    property var options: [] // [{ value, text }]
    signal picked(var value)

    readonly property string currentText: (options.find(o => o.value === value) || options[0] || {}).text || ""

    kind: "plain"
    implicitWidth: row_.implicitWidth + 2 * Ui.gapM
    Accessible.name: label + ": " + currentText
    onClicked: menu.popup(dd, 0, dd.height + 6)

    contentItem: Item {
        implicitWidth: row_.implicitWidth
        implicitHeight: row_.implicitHeight
        Row {
            id: row_
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dd.label
                color: dd.isKey ? Qt.alpha(dd.fg, 0.62) : dd.pal.panelTextDim
                font.family: "Nunito"
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dd.currentText
                color: dd.fg
                font.family: "Nunito"
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
