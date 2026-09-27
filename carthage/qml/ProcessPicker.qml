// "Link Game Process…": for launcher + game setups. Lists what started since the launch;
// choosing one tells Carthage that this is the real game, so it can track and quit it —
// now and every time after.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: picker

    property string gameId
    property string gameTitle
    property var items: []

    function openFor(gid, title) {
        gameId = gid
        gameTitle = title
        items = Backend.processesSince(gid)
        manual.text = Backend.relatedOf(gid)
        open()
    }
    function pick(name) {
        Backend.setRelated(gameId, name)
        close()
        Window.window.showPassiveNotification(
            name ? "Carthage will follow " + name + " for " + gameTitle : "Unlinked " + gameTitle, "short")
    }


    contentItem: Column {
        spacing: Ui.gapM
        Text {
            text: "Link Game Process"
            color: picker.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }
        Text {
            width: parent.width
            text: "If " + picker.gameTitle + " starts through a launcher, pick the actual game below. Carthage will then track it, show it as playing and quit it — every time."
            color: picker.pal.panelTextDim
            font.family: "Nunito"
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        Text {
            text: "Started since launch"
            color: picker.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
            topPadding: 4
        }
        Rectangle {
            width: parent.width
            height: Math.min(250, Math.max(44, list.contentHeight + 8))
            radius: Ui.radiusMedium
            color: picker.pal.panelHover
            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: picker.items
                QQC2.ScrollBar.vertical: CScrollBar { ink: Backend.theme.p.panelText }
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    width: list.width
                    height: 36
                    hoverEnabled: true
                    contentItem: Text {
                        text: modelData.name
                        color: picker.pal.panelText
                        font.family: "DM Mono"
                        font.pixelSize: Ui.textBody
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideMiddle
                    }
                    background: Rectangle {
                        radius: Ui.radiusSmall
                        color: parent.hovered ? picker.pal.panel : "transparent"
                    }
                    onClicked: picker.pick(modelData.name)
                }
                Text {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: "Nothing new has started yet."
                    color: picker.pal.panelTextDim
                    font.family: "Nunito"
                    font.pixelSize: Ui.textBody
                }
            }
        }
        Text {
            text: "Or type the program name"
            color: picker.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
            topPadding: 4
        }
        Row {
            width: parent.width
            spacing: Ui.gapS
            QQC2.TextField {
                id: manual
                width: parent.width - saveBtn.width - parent.spacing
                height: Ui.controlHeight
                leftPadding: 12
                placeholderText: "e.g. GenshinImpact.exe"
                placeholderTextColor: picker.pal.panelTextDim
                color: picker.pal.panelText
                font.family: "DM Mono"
                font.pixelSize: Ui.textBody
                selectByMouse: true
                onAccepted: picker.pick(text)
                background: Rectangle {
                    radius: Ui.radiusMedium
                    color: picker.pal.panelHover
                    border.width: manual.activeFocus ? 2 : 1
                    border.color: manual.activeFocus ? Backend.theme.accent.accent : picker.pal.panelBorder
                }
            }
            CButton {
                id: saveBtn
                kind: "primary"
                height: Ui.controlHeight
                text: "Save"
                onClicked: picker.pick(manual.text)
            }
        }
        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            CButton {
                visible: Backend.relatedOf(picker.gameId) !== ""
                text: "Unlink"
                onClicked: picker.pick("")
            }
            CButton {
                text: "Close"
                onClicked: picker.close()
            }
        }
    }
}
