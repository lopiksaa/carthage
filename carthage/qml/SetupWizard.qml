// First-run setup: what Carthage found, then the optional keys. Every step can be skipped.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

CDialog {
    id: wiz

    property Item appRoot
    property int step: 0
    property var found: []
    readonly property int lastStep: 3
    readonly property bool steamStep: Backend.keys.steamFound
    readonly property string stepKey: step === 1 ? "steamgrid" : step === 2 ? "steam" : ""
    readonly property bool keyDone: stepKey === "" || Backend.keys.has[stepKey] === true

    function start() {
        step = 0
        found = Backend.launcherSummary()
        open()
    }
    function next() {
        if (step >= lastStep) { close(); return }
        step++
        if (step === 2 && !steamStep) step++
    }
    function back() {
        step--
        if (step === 2 && !steamStep) step--
    }

    onClosed: Backend.setupFinished()

    maxWidth: 520
    closePolicy: QQC2.Popup.CloseOnEscape

    component Title_: Text {
        width: parent.width
        color: wiz.pal.panelText
        font.family: "Nunito"
        font.weight: Font.Black
        font.pixelSize: Ui.textTitle
        wrapMode: Text.Wrap
    }
    component Body_: Text {
        width: parent.width
        color: wiz.pal.panelTextDim
        font.family: "Nunito"
        font.pixelSize: Ui.textBody
        wrapMode: Text.Wrap
    }

    contentItem: Column {
        spacing: Ui.gapM
        Accessible.role: Accessible.Dialog
        Accessible.name: "Set up Carthage"

        Item {
            width: parent.width
            height: 20
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: wiz.steamStep ? wiz.lastStep + 1 : wiz.lastStep
                    delegate: Rectangle {
                        required property int index
                        readonly property int at: !wiz.steamStep && wiz.step > 2 ? wiz.step - 1 : wiz.step
                        width: index === at ? 18 : 6
                        height: 6
                        radius: 3
                        color: index <= at ? Backend.theme.accent.accent : wiz.pal.panelBorder
                        Behavior on width { NumberAnimation { duration: 140 } }
                    }
                }
            }
        }

        Column {
            visible: wiz.step === 0
            width: parent.width
            spacing: Ui.gapM
            Title_ { text: "Welcome to Carthage" }
            Body_ {
                text: wiz.found.length
                      ? "Your games are already here — Carthage reads them straight from your launchers:"
                      : "Carthage didn't find any launchers yet. It reads Steam, Battle.net, Heroic and Lutris on its own once they're installed, and you can add any other game by hand."
            }
            Column {
                visible: wiz.found.length > 0
                width: parent.width
                spacing: 4
                Repeater {
                    model: wiz.found
                    delegate: Row {
                        required property var modelData
                        spacing: Ui.gapS
                        CIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: "checkmark-symbolic"
                            isMask: true
                            color: Backend.theme.led.green
                        }
                        Text {
                            text: modelData.name + "  ·  " + modelData.count + (modelData.count === 1 ? " game" : " games")
                            color: wiz.pal.panelText
                            font.family: "Nunito"
                            font.weight: Font.Bold
                            font.pixelSize: Ui.textBody
                        }
                    }
                }
            }
            Body_ {
                text: wiz.steamStep
                      ? "Two free keys make Carthage better: one for cartridge art, one to show every Steam game you own. Both are optional — skip them and add them later in Menu → Accounts & Keys."
                      : "A free key fetches custom game art for your cartridges. It's optional — skip it and add it later in Menu → Accounts & Keys."
            }
        }

        Column {
            visible: wiz.step === 1
            width: parent.width
            spacing: Ui.gapM
            Title_ { text: "Cartridge art" }
            Body_ { text: "SteamGridDB has custom game art made by its community; this key fetches it for your cartridges — Steam, Battle.net and games you add yourself. Without this key most cartridges only get a plain printed label." }
            KeyRow {
                width: parent.width
                service: "steamgrid"
                title: "SteamGridDB API key"
                purpose: "Sign in on SteamGridDB, open Preferences → API, and copy the key."
                getUrl: "https://www.steamgriddb.com/profile/preferences/api"
            }
        }

        Column {
            visible: wiz.step === 2
            width: parent.width
            spacing: Ui.gapM
            Title_ { text: "Steam library and play time" }
            Body_ { text: "Steam's files on this PC only know games you've installed or played here. The Steam Web API key lets Carthage show every game you own, with your play time, so you can install them from the tray." }
            KeyRow {
                width: parent.width
                service: "steam"
                title: "Steam Web API key"
                purpose: "Any domain name works on Steam's form, e.g. localhost. Your game details must be public in Steam's privacy settings."
                getUrl: "https://steamcommunity.com/dev/apikey"
            }
        }
        Body_ {
            visible: wiz.stepKey !== ""
            font.pixelSize: Ui.textCaption
            text: "Keys stay in your system keyring (Credential Manager on Windows) and are only sent to their own service: SteamGridDB's key to steamgriddb.com, Steam's to api.steampowered.com."
        }

        Column {
            visible: wiz.step === wiz.lastStep
            width: parent.width
            spacing: Ui.gapM
            Title_ { text: "You're set" }
            Body_ { text: "Choose a cartridge to play it." }
        }

        Row {
            anchors.right: parent.right
            spacing: Ui.gapM
            topPadding: 6
            CButton {
                visible: wiz.step === 0
                text: "Skip Setup"
                onClicked: wiz.close()
            }
            CButton {
                visible: wiz.step > 0 && wiz.step < wiz.lastStep
                text: "Back"
                onClicked: wiz.back()
            }
            CButton {
                kind: "primary"
                text: wiz.step === 0 ? "Get Started" : wiz.step === wiz.lastStep ? "Start Playing" : wiz.keyDone ? "Next" : "Skip"
                onClicked: wiz.next()
            }
        }
    }
}
