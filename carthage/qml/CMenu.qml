// Carthage's context menu: a soft rounded panel instead of the system menu.
// Fill it with QQC2.Action items and CMenuSeparator. An action's objectName can be
// "danger" (painted red) or "optional" (hidden, not greyed out, while disabled — for items
// that don't apply to this game at all).
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Menu {
    id: cmenu  // not `menu`: each MenuItem has its own `menu` property, empty once it's removed
    // A click outside only closes the menu (it doesn't also reach what's underneath, e.g. the
    // game view's backdrop, which would close the whole view).
    modal: true
    dim: false

    readonly property var pal: Backend.theme.p

    // Counted while open (input behind is blocked meanwhile). A menu removed while open never
    // says "closed", so it also gives its count back when it's destroyed.
    property bool counted: false
    function release() {
        if (!counted) return
        counted = false
        Ui.openMenus = Math.max(0, Ui.openMenus - 1)
    }
    onOpened: if (!counted) { counted = true; Ui.openMenus++ }

    // Open from a button: below it, starting at its left edge, or ending at its right edge when
    // that side has no room; above it when there's no room below. (Qt alone would push the
    // menu over its own button.)
    function openFrom(button) {
        const win = button.Window.window
        const p = button.mapToItem(null, 0, 0)
        const w = Math.max(width, implicitWidth), h = Math.max(height, implicitHeight)
        const gap = 6
        const x = p.x + w > win.width - margins ? button.width - w : 0
        const below = p.y + button.height + gap + h <= win.height - margins
        const y = below || p.y - gap - h < margins ? button.height + gap : -gap - h
        popup(button, x, y)
    }
    onClosed: release()
    Component.onDestruction: release()

    padding: 6
    margins: 8
    implicitWidth: 230

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 * Backend.motion; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 110 * Backend.motion; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 70 * Backend.motion; easing.type: Easing.InCubic }
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
        readonly property color fg: danger ? cmenu.pal.dangerText : cmenu.pal.panelText

        implicitWidth: 230 - cmenu.leftPadding - cmenu.rightPadding
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
                font.family: Ui.fontButtons
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
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
                border.color: cmenu.pal.panelTextDim
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
            color: item.highlighted ? cmenu.pal.panelHover : "transparent"
        }
    }
}
