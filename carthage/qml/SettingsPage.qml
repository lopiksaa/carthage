// Settings as a page (sidebar layout concept): one panel filling the main area, the sections
// listed on its left and the chosen one on its right, like a settings window.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

FocusScope {
    id: page

    property Item appRoot
    property string section: "library"
    signal closeRequested()

    readonly property var pal: Backend.theme.p
    readonly property var sections: [
        { id: "library", title: "Library", icon: "view-grid-symbolic", blurb: "The tray and your games" },
        { id: "look", title: "Appearance", icon: "color-picker-symbolic", blurb: "Colors, fonts, card size" },
        { id: "sound", title: "Sound", icon: "audio-volume-high-symbolic", blurb: "Clicks and clunks" },
        { id: "store", title: "Store", icon: "internet-services-symbolic", blurb: "Steam and Epic, other stores" },
        { id: "keys", title: "Accounts & Keys", icon: "lock-symbolic", blurb: "Keys for art, Steam and prices" },
        { id: "system", title: "System", icon: "configure-symbolic", blurb: "Cache, art, updates, about" },
    ]
    readonly property var current: sections.find(s => s.id === section) || sections[0]
    readonly property bool narrow: width < 760  // the list shows icons only

    Keys.onEscapePressed: closeRequested()

    PanelBackground {
        anchors.fill: parent
        radius: Ui.radiusMedium + 4
        shadowOffset: 6
        shadowBlur: 24
        shadowOpacity: 0.3
    }

    // The sections.
    Column {
        id: nav
        x: Ui.gapM
        y: Ui.gapM
        width: page.narrow ? 52 : 236
        spacing: 2
        Repeater {
            model: page.sections
            delegate: QQC2.AbstractButton {
                id: head
                required property var modelData
                readonly property bool chosen: page.section === modelData.id
                width: nav.width
                height: page.narrow ? 44 : 54
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.title
                Accessible.selected: chosen
                Keys.onDownPressed: nextItemInFocusChain().forceActiveFocus()
                Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
                onClicked: { page.section = modelData.id; flick.contentY = 0 }
                QQC2.ToolTip.visible: page.narrow && hovered
                QQC2.ToolTip.text: modelData.title
                QQC2.ToolTip.delay: 300
                background: Rectangle {
                    radius: Ui.radiusMedium
                    color: head.chosen ? page.pal.panelHover
                         : head.hovered ? Qt.alpha(page.pal.panelHover, 0.55) : "transparent"
                    border.width: head.visualFocus ? 2 : 0
                    border.color: Ui.focusColor
                    Rectangle {  // the chosen one's mark
                        visible: head.chosen
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 20
                        radius: 1.5
                        color: Backend.theme.accent.accent
                    }
                }
                contentItem: Item {
                    CIcon {
                        id: navIcon
                        x: page.narrow ? Math.round((head.width - width) / 2) : 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        source: head.modelData.icon
                        color: head.chosen ? Backend.theme.accent.accent : page.pal.panelTextDim
                    }
                    Column {
                        visible: !page.narrow
                        anchors.left: navIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: head.modelData.title
                            color: page.pal.panelText
                            font.family: Ui.fontText
                            font.weight: head.chosen ? Font.Black : Font.Bold
                            font.pixelSize: Ui.textBody
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: head.modelData.blurb
                            color: page.pal.panelTextDim
                            font.family: Ui.fontText
                            font.pixelSize: Ui.textCaption
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: divider
        x: nav.x + nav.width + Ui.gapM
        y: Ui.gapL
        width: 1
        height: parent.height - 2 * Ui.gapL
        color: page.pal.panelBorder
    }

    // The chosen section.
    Flickable {
        id: flick
        anchors.left: divider.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2
        contentHeight: body.height + 2 * Ui.gapXL
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar { ink: page.pal.panelText }
        WheelAccel { flickable: flick; step: 90 }
        Column {
            id: body
            x: Ui.gapXL
            y: Ui.gapXL
            width: Math.min(flick.width - 2 * Ui.gapXL, 640)
            spacing: Ui.gapL
            Column {
                width: parent.width
                spacing: 2
                Text {
                    text: page.current.title
                    color: page.pal.panelText
                    font.family: Ui.fontTitles
                    font.weight: Font.Black
                    font.pixelSize: Ui.textTitle
                }
                Text {
                    text: page.current.blurb
                    color: page.pal.panelTextDim
                    font.family: Ui.fontText
                    font.pixelSize: Ui.textBody
                }
            }
            SettingsContent {
                width: parent.width
                appRoot: page.appRoot
                section: page.section
            }
        }
    }
}
