// A checkbox with its label; the whole row toggles. Same box as the menus' checkable items.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: cb

    readonly property var pal: Backend.theme.p

    checkable: true
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(28, row.implicitHeight)
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    background: Item {}
    contentItem: Item {
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.gapS
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: Ui.radiusTiny
                color: cb.checked ? Backend.theme.accent.accent : cb.hovered ? cb.pal.panelHover : "transparent"
                border.width: cb.visualFocus ? 2 : cb.checked ? 0 : 1.5
                border.color: cb.visualFocus ? Ui.focusColor : cb.pal.panelTextDim
                CIcon {
                    visible: cb.checked
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "checkmark-symbolic"
                    color: Backend.theme.accent.accentText
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cb.text
                color: cb.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
            }
        }
    }
}
