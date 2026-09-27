// The settings of one section of the drawer (SideDrawer lists the sections). Only that
// section's controls are created.
//   SettingsContent { section: "look" }
import QtQuick
import Carthage

Column {
    id: sc

    property Item appRoot
    property string section
    readonly property var pal: Backend.theme.p

    component Label_: Text {
        color: sc.pal.panelText
        font.family: "Nunito"
        font.weight: Font.Bold
        font.pixelSize: Ui.textBody
    }
    component Note: Text {
        width: parent.width
        color: sc.pal.panelTextDim
        font.family: "Nunito"
        font.pixelSize: Ui.textCaption
        wrapMode: Text.Wrap
        linkColor: Backend.theme.accent.accent
        // "whatsnew:" opens the What's new window; everything else is a web link.
        onLinkActivated: (url) => url === "whatsnew:" ? sc.appRoot.showWhatsNew() : Backend.openUrl(url)
        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
    component Section: Loader {
        property string sectionId
        active: sc.section === sectionId
        visible: active
        width: parent.width
    }

    // ------------------------------------------------------------ library
    Section {
        sectionId: "library"
        sourceComponent: Column {
            spacing: Ui.gapM
            CSwitch {
                width: parent.width
                text: "Installed games first"
                checked: Backend.settings.installedFirst
                onToggled: Backend.settings.installedFirst = checked
            }
            CSwitch {
                width: parent.width
                text: "Titles under cards"
                checked: Backend.settings.showTitles
                onToggled: Backend.settings.showTitles = checked
            }
            CSwitch {
                width: parent.width
                text: "Favorites shelf"
                hint: "A shelf above your games for the ones you keep coming back to"
                checked: Backend.settings.favoritesShelf
                onToggled: Backend.settings.favoritesShelf = checked
            }
            Row {
                width: parent.width
                spacing: Ui.gapS
                CButton {
                    width: (parent.width - Ui.gapS) / 2
                    text: "Add Game…"
                    icon.name: "list-add-symbolic"
                    onClicked: sc.appRoot.addGame()
                }
                CButton {
                    width: (parent.width - Ui.gapS) / 2
                    text: "Re-scan"
                    icon.name: "view-refresh-symbolic"
                    enabled: !Backend.fake
                    onClicked: {
                        Backend.rescan()
                        sc.appRoot.notify("Re-scanning your library…")
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ look & feel
    Section {
        sectionId: "look"
        sourceComponent: Column {
            id: look
            spacing: Ui.gapM
            // One chip size for both rows, so their colors line up in columns: as big as
            // fits the longer row (the cartridges': the colors, custom, "=") on one line.
            readonly property var options: Backend.theme.hardwareOptions
            readonly property real chipSize: Math.floor(Math.min(30, (width - (options.length + 1) * Ui.gapS) / (options.length + 2)))
            readonly property bool hifi: Backend.settings.skin === "hifi"
            // The skin: the machine around your games. Cartridges keep their own color in both.
            Label_ { visible: false; text: "Skin" }  // held back: only Classic ships for now
            CSegmented {
                visible: false
                width: parent.width
                value: Backend.settings.skin
                options: [
                    { value: "plastic", text: "Plastic" },
                    { value: "hifi", text: "Hi-Fi" },
                    { value: "classic", text: "Classic" },
                ]
                onPicked: (v) => { Backend.settings.skin = v; sc.appRoot.sound("key") }
            }
            // The plastic's color (the Hi-Fi skin is aluminum, so it has none).
            Label_ { visible: !look.hifi; text: "Hardware  ·  " + ((look.options.find(o => o.value === Backend.settings.hardware) || {}).text || "Custom") }
            Row {
                visible: !look.hifi
                spacing: Ui.gapS
                Repeater {
                    model: look.options
                    delegate: ColorChip {
                        required property var modelData
                        size: look.chipSize
                        label: modelData.text
                        plastic: modelData.color
                        selected: Backend.settings.hardware === modelData.value
                        onPicked: Backend.settings.hardware = modelData.value
                    }
                }
                ColorChip {
                    size: look.chipSize
                    label: "Hardware: custom color"
                    rainbow: !Backend.settings.hardware.startsWith("c_")
                    plastic: Backend.settings.hardware.startsWith("c_") ? Backend.theme.plasticOf(Backend.settings.hardware) : "transparent"
                    selected: Backend.settings.hardware.startsWith("c_")
                    onPicked: sc.appRoot.pickColor("hardware")
                }
            }
            Label_ { text: "Cartridges  ·  " + (Backend.settings.cardColor === "same" ? (look.hifi ? "Same as the Plastic skin" : "Same as hardware")
                        : ((look.options.find(o => o.value === Backend.settings.cardColor) || {}).text || "Custom")) }
            // Cartridge plastic, separate from the hardware; "=" (last) follows the hardware.
            Row {
                spacing: Ui.gapS
                Repeater {
                    model: look.options
                    delegate: ColorChip {
                        required property var modelData
                        size: look.chipSize
                        label: "Cartridges: " + modelData.text
                        plastic: modelData.color
                        selected: Backend.settings.cardColor === modelData.value
                        onPicked: Backend.settings.cardColor = modelData.value
                    }
                }
                ColorChip {
                    size: look.chipSize
                    label: "Cartridges: custom color"
                    rainbow: !Backend.settings.cardColor.startsWith("c_")
                    plastic: Backend.settings.cardColor.startsWith("c_") ? Backend.theme.plasticOf(Backend.settings.cardColor) : "transparent"
                    selected: Backend.settings.cardColor.startsWith("c_")
                    onPicked: sc.appRoot.pickColor("card")
                }
                ColorChip {
                    size: look.chipSize
                    label: "Cartridges: same as hardware"
                    selected: Backend.settings.cardColor === "same"
                    onPicked: Backend.settings.cardColor = "same"
                }
            }
            Label_ { text: "Card size" }
            CSegmented {
                width: parent.width
                readonly property int size: Backend.settings.cardWidth
                value: size <= 132 ? 132 : size >= 178 ? 186 : 150
                options: [
                    { value: 132, text: "Small" },
                    { value: 150, text: "Medium" },
                    { value: 186, text: "Large" },
                ]
                onPicked: (v) => Backend.settings.cardWidth = v
            }
            Column {
                width: parent.width
                spacing: 2
                CSwitch {
                    width: parent.width
                    text: "Tilt cards on hover"
                    checked: Backend.settings.tiltEnabled
                    onToggled: Backend.settings.tiltEnabled = checked
                }
                CSwitch {
                    visible: !look.hifi  // aluminum has its own brushed finish
                    width: parent.width
                    text: "Textured plastic"
                    hint: "A pebbled finish on the hardware"
                    checked: Backend.settings.texturedPlastic
                    onToggled: Backend.settings.texturedPlastic = checked
                }
                CSwitch {
                    width: parent.width
                    text: "Retro screen effects"
                    hint: "A power-on flicker when Carthage starts"
                    checked: Backend.settings.crtEffects
                    onToggled: Backend.settings.crtEffects = checked
                }
                CSwitch {
                    width: parent.width
                    text: "Prefer official Steam art"
                    hint: "Steam's own banner and logo over SteamGridDB"
                    checked: Backend.settings.preferOfficialArt
                    onToggled: Backend.settings.preferOfficialArt = checked
                }
            }
        }
    }

    // ------------------------------------------------------------ sound
    Section {
        sectionId: "sound"
        sourceComponent: Column {
            spacing: Ui.gapM
            CSwitch {
                width: parent.width
                text: "Sounds"
                hint: "Clicks when cartridges move"
                checked: Backend.settings.soundsEnabled
                onToggled: Backend.settings.soundsEnabled = checked
            }
            CSegmented {
                enabled: Backend.settings.soundsEnabled
                opacity: enabled ? 1 : 0.45
                width: parent.width
                value: Backend.settings.soundVolume
                options: [
                    { value: 0.12, text: "Quiet" },
                    { value: 0.3, text: "Medium" },
                    { value: 0.65, text: "Loud" },
                ]
                onPicked: (v) => {
                    Backend.settings.soundVolume = v
                    sc.appRoot.sound("pick")
                }
            }
        }
    }

    // ------------------------------------------------------------ store
    Section {
        sectionId: "store"
        sourceComponent: Column {
            spacing: Ui.gapM
            CSwitch {
                width: parent.width
                text: "Hide adult content"
                hint: "Games Steam marks for nudity or sexual content"
                checked: Backend.settings.hideAdult
                onToggled: Backend.settings.hideAdult = checked
            }
            CSwitch {
                width: parent.width
                text: "Other stores"
                hint: Backend.keys.has["itad"] ? "Prices from GOG, Microsoft Store, EA and Battle.net too, from IsThereAnyDeal"
                                                : "Prices from GOG, Microsoft Store, EA and Battle.net too. Needs an IsThereAnyDeal key (Keys)"
                enabled: Backend.keys.has["itad"] === true
                checked: Backend.settings.otherStores && Backend.keys.has["itad"] === true
                onToggled: Backend.settings.otherStores = checked
            }
            Note {
                text: "Prices, reviews and screenshots come from the public <a href=\"https://store.steampowered.com\">Steam store</a> and <a href=\"https://store.epicgames.com\">Epic Games Store</a>; other stores' prices from <a href=\"https://isthereanydeal.com\">IsThereAnyDeal</a>. Buying and wishlisting happen in each store."
            }
        }
    }

    // ------------------------------------------------------------ keys
    Section {
        sectionId: "keys"
        sourceComponent: Column {
            spacing: Ui.gapM
            KeyRow {
                width: parent.width
                service: "steamgrid"
                title: "SteamGridDB"
                purpose: "Fetches custom game art for your cartridges from SteamGridDB's website. Without it most cartridges only get a plain printed label."
                getUrl: "https://www.steamgriddb.com/profile/preferences/api"
            }
            KeyRow {
                width: parent.width
                service: "steam"
                title: "Steam Web API"
                purpose: "Shows every Steam game you own, not only the ones installed or played on this PC. Any domain name works on Steam's form, e.g. localhost."
                getUrl: "https://steamcommunity.com/dev/apikey"
            }
            KeyRow {
                width: parent.width
                service: "itad"
                title: "IsThereAnyDeal (experimental, not tested)"
                purpose: "For the store's other stores: what GOG, Microsoft Store, EA and Battle.net ask for a game. Register an app on IsThereAnyDeal to get its key."
                getUrl: "https://isthereanydeal.com/apps/my/"
            }
            Note {
                text: "Keys are kept in your system keyring and only sent to their own service. Never paste your Steam key into a website — you can <a href=\"https://steamcommunity.com/dev/apikey\">revoke it</a> any time."
            }
            CButton {
                width: parent.width
                text: "Run Setup Again…"
                onClicked: sc.appRoot.runSetup()
            }
        }
    }

    // ------------------------------------------------------------ system
    Section {
        sectionId: "system"
        sourceComponent: Column {
            spacing: Ui.gapM
            CSwitch {
                width: parent.width
                text: "Test Cartridge"
                hint: "A pretend game for trying the dock — launches nothing"
                checked: Backend.settings.testCartridge
                onToggled: Backend.settings.testCartridge = checked
            }
            Column {
                width: parent.width
                spacing: Ui.gapS
                CButton {
                    width: parent.width
                    property string size: ""
                    text: "Clear Cache" + (size ? "  ·  " + size : "")
                    icon.name: "edit-clear-all-symbolic"
                    enabled: !Backend.fake
                    Component.onCompleted: size = Backend.fake ? "" : Backend.cacheSize()
                    onClicked: sc.appRoot.confirmClearCache(() => {
                        const freed = Backend.clearCache()
                        size = Backend.cacheSize()
                        sc.appRoot.notify("Cleared " + freed + ". Art will download again in the background.")
                    })
                }
                CButton {
                    width: parent.width
                    text: "Retry Missing Art"
                    icon.name: "insert-image-symbolic"
                    enabled: !Backend.fake
                    onClicked: {
                        Backend.artPicker.retryMissing()
                        sc.appRoot.notify("Looking for missing art again…")
                    }
                }
                CButton {
                    width: parent.width
                    text: "Reset All Settings…"
                    icon.name: "edit-undo-symbolic"
                    onClicked: sc.appRoot.confirmResetSettings()
                }
            }
            CSwitch {
                width: parent.width
                text: "Discord Rich Presence"
                hint: "Discord shows Choosing a Game or Browsing Store. Nothing about your games is shared"
                checked: Backend.settings.discordPresence
                onToggled: Backend.settings.discordPresence = checked
            }
            CSwitch {
                width: parent.width
                text: Backend.updater.automatic ? "Update automatically" : "Check for updates"
                hint: Backend.updater.automatic ? "Downloads new versions and installs them when Carthage restarts"
                                                 : "Asks GitHub for the latest Carthage release"
                checked: Backend.settings.checkUpdates
                onToggled: {
                    Backend.settings.checkUpdates = checked
                    if (checked) Backend.updater.check()
                }
            }
            CButton {
                visible: Backend.updater.available && Backend.updater.state !== "downloading"
                width: parent.width
                kind: "primary"
                readonly property bool ready: Backend.updater.state === "ready"
                text: ready ? "Restart to Update to " + Backend.updater.latest : "Download Carthage " + Backend.updater.latest
                icon.name: ready ? "view-refresh-symbolic" : "download-symbolic"
                onClicked: ready ? Backend.updater.restartNow() : Backend.updater.download()
            }
            Note {
                topPadding: 4
                text: "Carthage " + Backend.updater.version
                      + (Backend.updater.checking ? "  ·  Checking…"
                         : Backend.updater.state === "downloading" ? "  ·  Downloading " + Backend.updater.latest + "… " + Math.round(Backend.updater.progress * 100) + "%"
                         : Backend.updater.state === "ready" ? "  ·  " + Backend.updater.latest + " is ready"
                         : Backend.updater.available ? "  ·  Version " + Backend.updater.latest + " is out"
                         : Backend.updater.latest ? "  ·  Up to date" : "")
                      + "<br><a href=\"whatsnew:\">What's new</a>  ·  <a href=\"https://github.com/lopiksaa/carthage/releases\">All release notes</a>"
            }
            // About: the license and how Carthage is made.
            Note {
                text: "Built using Claude. Carthage is free software under the "
                      + "<a href=\"https://www.gnu.org/licenses/gpl-3.0.html\">GNU GPL v3</a>: "
                      + "<a href=\"https://github.com/lopiksaa/carthage\">source code</a>  ·  "
                      + "<a href=\"https://github.com/lopiksaa/carthage/blob/main/THIRD_PARTY_NOTICES.md\">third-party notices</a>"
            }
        }
    }
}
