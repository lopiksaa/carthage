// "Change Header…": what the strip at the top of a cartridge shows, each option previewed.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

CDialog {
    id: picker

    property string gameId
    property string gameTitle
    property string source
    readonly property string current: Backend.headerTick >= 0 && gameId ? Backend.headerOf(gameId) : "launcher"
    readonly property var options: [
        { value: "launcher", text: "Launcher", hint: "Where the game comes from (Steam, Heroic…)" },
        { value: "logo", text: "Game Logo", hint: "The game's own logo" },
        { value: "title", text: "Game Title", hint: "The name, printed" },
        { value: "carthage", text: "Carthage", hint: "A Carthage label" },
        { value: "none", text: "Blank", hint: "Just the plastic" },
        { value: "text", text: "Custom Text", hint: "Type your own label" },
        { value: "image", text: "Custom Image", hint: "Use an image file of your own" },
    ]

    function openFor(gid, title, src) {
        gameId = gid
        gameTitle = title
        source = src
        open()
        if (Backend.artPicker) Backend.artPicker.fetch_logo_slot(gid) // none in the demo library
    }

    property Item appRoot

    FileDialog {
        id: fileDialog
        title: "Choose a header image for " + picker.gameTitle
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg)"]
        onAccepted: {
            const path = Backend.localPath(selectedFile)
            Backend.setHeaderImage(picker.gameId, path)
            picker.close()
        }
    }


    contentItem: Column {
        spacing: Ui.gapS
        Text {
            text: "Cartridge Header"
            color: picker.pal.panelText
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Ui.textTitle
        }
        Text {
            width: parent.width
            bottomPadding: 6
            text: picker.gameTitle
            color: picker.pal.panelTextDim
            font.family: "Nunito"
            font.pixelSize: Ui.textBody
            elide: Text.ElideRight
        }
        Repeater {
            model: picker.options
            delegate: QQC2.AbstractButton {
                id: opt
                required property var modelData
                readonly property bool selected: picker.current === modelData.value
                width: parent.width
                height: 64
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.text
                Accessible.checked: selected
                onClicked: {
                    if (modelData.value === "text") {
                        const gid = picker.gameId, title = picker.gameTitle
                        picker.close()
                        picker.appRoot.customHeaderText(gid, title)
                    } else if (modelData.value === "image") {
                        fileDialog.open()
                    } else {
                        Backend.setHeader(picker.gameId, modelData.value)
                        picker.close()
                    }
                }
                background: Rectangle {
                    radius: Ui.radiusMedium
                    color: opt.selected ? Qt.alpha(Backend.theme.accent.accent, 0.14)
                         : opt.hovered ? picker.pal.panelHover : "transparent"
                    border.width: opt.selected ? 2 : (opt.visualFocus ? 2 : 0)
                    border.color: opt.visualFocus ? Ui.focusColor : Backend.theme.accent.accent
                }
                contentItem: Item {
                    // A live preview of the strip, on the cartridge's sticker color.
                    Rectangle {
                        id: swatch
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        height: 50
                        radius: Ui.radiusSmall
                        color: Backend.theme.cp.stickerHead
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.2)
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: picker.gameId ? "image://gc/header/" + opt.modelData.value + "/" + (picker.source || "other")
                                                    + "/" + Backend.theme.cardEdition + "/" + picker.gameId
                                                    + "?h=" + Backend.headerTick : ""
                            sourceSize: Qt.size(300, 100)
                            smooth: true
                            cache: false
                        }
                    }
                    Column {
                        anchors.left: swatch.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: opt.modelData.text
                            color: picker.pal.panelText
                            font.family: "Nunito"
                            font.weight: opt.selected ? Font.Black : Font.Bold
                            font.pixelSize: Ui.textBody
                        }
                        Text {
                            width: parent.width
                            text: opt.modelData.hint
                            color: picker.pal.panelTextDim
                            font.family: "Nunito"
                            font.pixelSize: Ui.textCaption
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
