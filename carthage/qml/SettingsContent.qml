// One settings section of the drawer; only its controls are created.
//   SettingsContent { section: "look" }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Column {
    id: sc

    property Item appRoot
    property string section
    readonly property var pal: Backend.theme.p

    component Label_: Text {
        color: sc.pal.panelText
        font.family: Ui.fontText
        font.weight: Font.Bold
        font.pixelSize: Ui.textBody
    }
    // One kind of text's font: a row showing the current font (written in it) that unfolds
    // the choices, each written in its own font. Only one row is open at a time.
    // A setting with a few named choices, folded until opened: fonts (each shown in itself)
    // or, with `names`, anything else.
    component Choice: Column {
        id: fc
        property string label
        property string key        // the setting, e.g. "fontLabels"
        property var choices: []
        property string current    // the value in use
        property var names: null   // value → shown name; null = the values are fonts
        function nameOf(v) { return names ? names[v] || v : v }
        function fontOf(v) { return names ? Ui.fontText : v }
        readonly property bool open: parent.openKey === key
        width: parent.width
        spacing: Ui.gapXS
        QQC2.AbstractButton {
            id: head
            width: parent.width
            height: Ui.controlHeight
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.Button
            Accessible.name: fc.label + ": " + fc.nameOf(fc.current)
            onClicked: fc.parent.openKey = fc.open ? "" : fc.key
            background: Rectangle {
                radius: Ui.radiusSmall
                color: head.hovered ? sc.pal.panelHover : Qt.alpha(sc.pal.panelHover, 0.5)
                border.width: head.visualFocus ? 2 : 0
                border.color: Ui.focusColor
            }
            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Ui.gapM
                    anchors.verticalCenter: parent.verticalCenter
                    text: fc.label
                    color: sc.pal.panelTextDim
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textCaption
                }
                Text {
                    anchors.right: arrow.left
                    anchors.rightMargin: Ui.gapS
                    anchors.verticalCenter: parent.verticalCenter
                    text: fc.nameOf(fc.current)
                    color: sc.pal.panelText
                    font.family: fc.fontOf(fc.current)
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textBody
                }
                CIcon {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: Ui.gapM
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    source: fc.open ? "go-up-symbolic" : "go-down-symbolic"
                    color: sc.pal.panelTextDim
                }
            }
        }
        Flow {
            visible: fc.open
            width: parent.width
            spacing: Ui.gapXS
            bottomPadding: Ui.gapS
            Repeater {
                model: fc.choices
                delegate: QQC2.AbstractButton {
                    id: chip
                    required property string modelData
                    readonly property bool chosen: fc.current === modelData
                    width: Math.min(fc.width, implicitWidth)
                    implicitWidth: chipText.implicitWidth + 2 * Ui.gapM
                    height: Ui.controlHeight - 4
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: fc.label + ": " + fc.nameOf(modelData)
                    Accessible.checked: chosen
                    onClicked: { Backend.settings[fc.key] = modelData; sc.appRoot.sound("key") }
                    background: Rectangle {
                        radius: Ui.radiusSmall
                        color: chip.chosen ? Backend.theme.accent.accent
                             : chip.hovered ? sc.pal.panelHover : Qt.alpha(sc.pal.panelHover, 0.5)
                        border.width: chip.visualFocus ? 2 : 0
                        border.color: Ui.focusColor
                    }
                    contentItem: Text {
                        id: chipText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: fc.nameOf(chip.modelData)
                        color: chip.chosen ? Backend.theme.accent.accentText : sc.pal.panelText
                        font.family: fc.fontOf(chip.modelData)
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textBody
                    }
                }
            }
        }
    }
    component Note: Text {
        width: parent.width
        color: sc.pal.panelTextDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textCaption
        wrapMode: Text.Wrap
        linkColor: Backend.theme.accent.accent
        onLinkActivated: (url) => url === "whatsnew:" ? sc.appRoot.showWhatsNew() : Backend.openUrl(url)
        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
    component Section: Loader {
        property string sectionId
        active: sc.section === sectionId
        visible: active
        width: parent.width
    }

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

    Section {
        sectionId: "look"
        sourceComponent: Column {
            id: look
            spacing: Ui.gapM
            // One chip size for both color grids, so their colors line up in columns.
            readonly property var options: Backend.theme.hardwareOptions
            readonly property real chipSize: 30
            Label_ { text: "Hardware  ·  " + ((look.options.find(o => o.value === Backend.settings.hardware) || {}).text || "Custom") }
            Flow {
                width: parent.width
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
            Label_ { text: "Cartridges  ·  " + (Backend.settings.cardColor === "same" ? "Same as hardware"
                        : ((look.options.find(o => o.value === Backend.settings.cardColor) || {}).text || "Custom")) }
            Flow {
                width: parent.width
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
            Label_ { text: "Fonts" }
            Column {
                width: parent.width
                spacing: Ui.gapXS
                property string openKey: "" // the kind of text whose choices are showing
                Choice { label: "Labels"; key: "fontLabels"; choices: Ui.labelFonts; current: Ui.fontLabels }
                Choice { label: "Game titles"; key: "fontTitles"; choices: Ui.titleFonts; current: Ui.fontTitles }
                Choice { label: "Buttons"; key: "fontButtons"; choices: Ui.buttonFonts; current: Ui.fontButtons }
                Choice { label: "Text"; key: "fontText"; choices: Ui.textFonts; current: Ui.fontText }
            }
            Label_ { text: "Plastic" }
            Column {
                width: parent.width
                property string openKey: ""
                Choice {
                    label: "Texture"
                    key: "plasticTexture"
                    choices: Backend.theme.textureOptions.map(o => o.value)
                    names: Backend.theme.textureOptions.reduce((m, o) => { m[o.value] = o.text; return m }, {})
                    current: Backend.settings.plasticTexture
                }
            }
            Label_ { text: "Card size" }
            Row { // − ● ● ● ○ ○ ○ +  : card widths in steps of 18 px (the old presets are steps 2, 3 and 5)
                id: sizer
                readonly property var steps: [114, 132, 150, 168, 186, 204]
                // The step nearest the saved width (an older saved size may fall between steps).
                readonly property int index: {
                    let best = 0
                    for (let i = 1; i < steps.length; i++)
                        if (Math.abs(steps[i] - Backend.settings.cardWidth) < Math.abs(steps[best] - Backend.settings.cardWidth)) best = i
                    return best
                }
                function go(d) {
                    const i = Math.max(0, Math.min(steps.length - 1, index + d))
                    if (i === index) return
                    Backend.settings.cardWidth = steps[i]
                    sc.appRoot.sound("key")
                }
                spacing: Ui.gapM
                Accessible.role: Accessible.Grouping
                Accessible.name: "Card size, step " + (index + 1) + " of " + steps.length
                CButton {
                    icon.name: "list-remove-symbolic"
                    enabled: sizer.index > 0
                    Accessible.name: "Smaller cards"
                    onClicked: sizer.go(-1)
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Ui.gapS
                    Repeater {
                        model: sizer.steps.length
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: index <= sizer.index ? Backend.theme.accent.accent : Qt.alpha(sc.pal.panelText, 0.18)
                            Behavior on color { ColorAnimation { duration: 100 * Backend.motion } }
                        }
                    }
                }
                CButton {
                    icon.name: "list-add-symbolic"
                    enabled: sizer.index < sizer.steps.length - 1
                    Accessible.name: "Bigger cards"
                    onClicked: sizer.go(1)
                }
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
                    width: parent.width
                    text: "Textured plastic"
                    hint: "The plastic texture on the hardware too"
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
            Note {
                text: "Built using Claude. Carthage is free software under the "
                      + "<a href=\"https://www.gnu.org/licenses/gpl-3.0.html\">GNU GPL v3</a>: "
                      + "<a href=\"https://github.com/lopiksaa/carthage\">source code</a>  ·  "
                      + "<a href=\"https://github.com/lopiksaa/carthage/blob/main/THIRD_PARTY_NOTICES.md\">third-party notices</a>"
            }
        }
    }
}
