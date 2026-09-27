// Carthage's context menu: a soft rounded panel instead of the system menu.
// Fill it with QQC2.Action items and CMenuSeparator. An action's objectName can be
// "danger" (painted red) or "optional" (hidden, not greyed out, while disabled — for items
// that don't apply to this game at all).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Menu {
    id: menu

    readonly property var pal: Backend.theme.p

    onOpened: Ui.openMenus++
    onClosed: Ui.openMenus = Math.max(0, Ui.openMenus - 1)

    padding: 6
    margins: 8
    implicitWidth: 230

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 110; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 70 }
    }

    background: PanelBackground {
        implicitWidth: 230
        radius: Ui.radiusMedium
        shadowOffset: 6
        shadowBlur: 22
        shadowOpacity: Backend.theme.dark ? 0.5 : 0.22
    }

    delegate: QQC2.MenuItem {
        id: item

        readonly property bool danger: action !== null && action.objectName === "danger"
        readonly property bool hiddenOptional: action !== null && action.objectName === "optional" && !action.enabled
        visible: !hiddenOptional
        readonly property color fg: danger ? menu.pal.dangerText : menu.pal.panelText

        implicitWidth: 230 - menu.leftPadding - menu.rightPadding
        implicitHeight: hiddenOptional ? 0 : 38
        leftPadding: 12
        rightPadding: 12

        contentItem: Item {
            CIcon {
                id: itemIcon
                visible: item.icon.name !== ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: item.icon.name
                isMask: true
                color: item.fg
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: check.left
                anchors.verticalCenter: parent.verticalCenter
                text: item.text
                color: item.fg
                opacity: item.enabled ? 1 : 0.45
                font.family: "Nunito"
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
            // A drawn checkbox: an empty rounded box, filled with a tick when on.
            Rectangle {
                id: check
                visible: item.checkable
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: item.checkable ? 18 : 0
                height: 18
                radius: Ui.radiusTiny
                color: item.checked ? Backend.theme.accent.accent : "transparent"
                border.width: item.checked ? 0 : 1.5
                border.color: menu.pal.panelTextDim
                CIcon {
                    visible: item.checked
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "checkmark-symbolic"
                    isMask: true
                    color: Backend.theme.accent.accentText
                }
            }
        }
        indicator: Item {}
        arrow: Item {}
        background: Rectangle {
            radius: Ui.radiusSmall
            color: item.highlighted ? menu.pal.panelHover : "transparent"
        }
    }
}
