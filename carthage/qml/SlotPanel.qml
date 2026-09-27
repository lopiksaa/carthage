// The panel above a docked cartridge: its status and Quit / Eject.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.Popup {
    id: panel

    property Item slot: null // the DockSlot this panel belongs to
    property Item appRoot

    readonly property var pal: Backend.theme.p
    readonly property bool tracked: slot ? slot.tracked : true
    readonly property string state_: slot ? slot.state_ : ""

    function openFor(s) {
        slot = s
        const top = s.cartTopLeft(parent) // top-left of the cartridge sticking out
        x = Math.round(top.x + s.cartW / 2 - width / 2)
        y = Math.round(top.y - height - 14)
        open()
        quitButton.forceActiveFocus()
    }

    width: 280
    padding: Ui.gapL
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 }
        NumberAnimation { property: "y"; from: panel.y + 8; to: panel.y; duration: 160; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
    }

    background: PanelBackground {
        radius: Ui.radiusLarge
        shadowOffset: 8
        shadowBlur: 26
        shadowOpacity: Backend.theme.dark ? 0.55 : 0.25
        Rectangle {
            width: 14
            height: 14
            rotation: 45
            x: parent.width / 2 - 7
            y: parent.height - 8
            color: panel.pal.panel
            border.width: 1
            border.color: panel.pal.panelBorder
            z: -1
        }
        Rectangle { // hides the pointer's inner border line
            width: 22
            height: 8
            x: parent.width / 2 - 11
            y: parent.height - 9
            color: panel.pal.panel
        }
    }

    contentItem: Column {
        spacing: Ui.gapM

        Column {
            width: parent.width
            spacing: 2
            Text {
                width: parent.width
                text: panel.slot ? panel.slot.title : ""
                color: panel.pal.panelText
                font.family: "Nunito"
                font.weight: Font.Black
                font.pixelSize: Ui.textLead
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Row {
                spacing: Ui.gapS
                Led {
                    anchors.verticalCenter: parent.verticalCenter
                    glow: false
                    color: !panel.slot ? "transparent"
                         : panel.slot.led === "green" ? Backend.theme.led.green : Backend.theme.led.amber
                }
                Text {
                    text: panel.slot ? panel.slot.statusText : ""
                    color: panel.pal.panelTextDim
                    font.family: "Nunito"
                    font.weight: Font.DemiBold
                    font.pixelSize: Ui.textBody
                }
            }
        }

        Row {
            visible: panel.state_ === "notresponding"
            width: parent.width
            spacing: Ui.gapS
            CButton {
                width: (parent.width - 8) / 2
                kind: "danger"
                text: "Force Quit"
                onClicked: {
                    const s = panel.slot
                    panel.close()
                    panel.appRoot.confirmQuit(s.gameId, s.title, true)
                }
            }
            CButton {
                width: (parent.width - 8) / 2
                text: "Keep Waiting"
                onClicked: {
                    Backend.sessions.keepWaiting(panel.slot.gameId)
                    panel.close()
                }
            }
        }

        CButton {
            visible: panel.slot !== null && Backend.sessions.canSwitch(panel.slot.gameId)
            width: parent.width
            kind: "primary"
            text: "Switch to Game"
            icon.name: "window-symbolic"
            onClicked: {
                Backend.sessions.switchTo(panel.slot.gameId)
                panel.close()
            }
        }

        CButton {
            width: parent.width
            text: Backend.relatedOf(panel.slot ? panel.slot.gameId : "") ? "Game Process: " + Backend.relatedOf(panel.slot.gameId)
                                                                         : "Link Game Process…"
            icon.name: "link-symbolic"
            onClicked: {
                const s = panel.slot
                panel.close()
                panel.appRoot.linkProcess(s.gameId, s.title)
            }
        }

        CButton {
            id: otherButton
            width: parent.width
            text: "Other"
            icon.name: "overflow-menu-symbolic"
            onClicked: editMenu.popup(otherButton, 0, otherButton.height + 6)
        }

        CButton {
            id: quitButton
            visible: panel.state_ !== "notresponding"
            width: parent.width
            kind: panel.tracked ? "danger" : "plain"
            text: panel.tracked ? "Quit Game" : "Eject Card"
            icon.name: panel.tracked ? "system-shutdown-symbolic" : "media-eject-symbolic"
            enabled: panel.state_ === "running" || panel.state_ === "starting" || panel.state_ === "handoff"
            onClicked: {
                const s = panel.slot
                panel.close()
                if (panel.tracked) panel.appRoot.confirmQuit(s.gameId, s.title, false)
                else Backend.sessions.eject(s.gameId)
            }
        }
        Text {
            visible: !panel.tracked
            width: parent.width
            text: "Carthage can't see when games started through another launcher close. Eject the card when you're done."
            color: panel.pal.panelTextDim
            font.family: "Nunito"
            font.pixelSize: Ui.textCaption
            wrapMode: Text.Wrap
        }
    }

    CMenu {
        id: editMenu
        function run(fn) {
            const s = panel.slot
            panel.close()
            fn(s)
        }
        QQC2.Action {
            text: "Change Art…"
            icon.name: "insert-image-symbolic"
            enabled: !Backend.fake
            onTriggered: editMenu.run(s => panel.appRoot.changeArt(s.gameId, s.title))
        }
        QQC2.Action {
            text: "Reposition Art…"
            icon.name: "transform-move-symbolic"
            enabled: !Backend.fake
            onTriggered: editMenu.run(s => panel.appRoot.repositionArt(s.gameId, s.title))
        }
        QQC2.Action {
            text: "Change Header…"
            icon.name: "view-media-title-symbolic"
            onTriggered: editMenu.run(s => panel.appRoot.changeHeader(s.gameId, s.title, s.source))
        }
        QQC2.Action {
            text: "Rename…"
            icon.name: "edit-rename-symbolic"
            enabled: !Backend.fake
            onTriggered: editMenu.run(s => panel.appRoot.renameGame(s.gameId, s.title))
        }
        QQC2.Action {
            text: "Edit Play Time…"
            icon.name: "chronometer-symbolic"
            objectName: "optional" // Steam keeps its own count
            enabled: panel.slot !== null && Backend.playtimeEditable(panel.slot.gameId)
            onTriggered: editMenu.run(s => panel.appRoot.editPlaytime(s.gameId, s.title))
        }
        CMenuSeparator {}
        QQC2.Action {
            text: "Show in Tray"
            icon.name: "view-grid-symbolic"
            onTriggered: editMenu.run(s => panel.appRoot.showInTray(s.gameId))
        }
    }
}
