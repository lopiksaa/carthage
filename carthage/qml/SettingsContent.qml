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
    // A row that unfolds more settings below it, naming what they're set to while folded.
    component FoldHead: QQC2.AbstractButton {
        id: fh
        property string title
        property string summary
        property bool open
        property string arrow: open ? "go-up-symbolic" : "go-down-symbolic"
        width: parent.width
        height: Ui.controlHeight
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.Button
        Accessible.name: title + ": " + summary + (open ? ", open" : ", choose to customize")
        background: Rectangle {
            radius: Ui.radiusSmall
            color: fh.hovered ? sc.pal.panelHover : Qt.alpha(sc.pal.panelHover, 0.5)
            border.width: fh.visualFocus ? 2 : 0
            border.color: Ui.focusColor
        }
        contentItem: Item {
            Text {
                id: fhTitle
                anchors.left: parent.left
                anchors.leftMargin: Ui.gapM
                anchors.verticalCenter: parent.verticalCenter
                text: fh.title
                color: sc.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
            }
            Text {
                anchors.left: fhTitle.right
                anchors.leftMargin: Ui.gapL
                anchors.right: fhArrow.left
                anchors.rightMargin: Ui.gapS
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: fh.open ? "" : fh.summary
                color: sc.pal.panelTextDim
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
            }
            CIcon {
                id: fhArrow
                anchors.right: parent.right
                anchors.rightMargin: Ui.gapM
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: fh.arrow
                color: sc.pal.panelTextDim
            }
        }
    }
    // A slider with its name and value:  SliderRow { label: "Speed"; value: "1.0×"; CSlider { anchors.fill: parent } }
    component SliderRow: Item {
        id: sr
        property string label
        property string value
        default property alias content: holder.data
        width: parent.width
        height: 30
        Text {
            id: srLabel
            anchors.left: parent.left
            anchors.leftMargin: Ui.gapM
            anchors.verticalCenter: parent.verticalCenter
            width: 128
            elide: Text.ElideRight
            text: sr.label
            color: sc.pal.panelTextDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
        }
        Item {
            id: holder
            anchors.left: srLabel.right
            anchors.right: srValue.left
            anchors.rightMargin: Ui.gapS
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
        Text {
            id: srValue
            anchors.right: parent.right
            anchors.rightMargin: Ui.gapS
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            horizontalAlignment: Text.AlignRight
            text: sr.value
            color: sc.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
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
                visible: false  // the sidebar concept: Favorites is a page, not a shelf
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
            // One chip size for both color rows, so their colors line up in columns.
            readonly property var options: Backend.theme.hardwareOptions
            readonly property var suggested: options.filter(o => o.suggested)
            readonly property real chipSize: 30
            function isSuggested(value) { return suggested.some(o => o.value === value) }
            function nameOf(value) { return (options.find(o => o.value === value) || {}).text || "Custom" }
            // Glass: the ground. Advanced holds its colours one by one and every other variable.
            readonly property var tuningSpec: Backend.theme.groundTuningSpec
            readonly property string style: ["mesh", "rays", "iris", "topo", "still"].indexOf(Backend.settings.background) >= 0
                                            ? Backend.settings.background : "mesh"
            function groundName(value) { return (Backend.theme.groundOptions.find(o => o.value === value) || {}).text || "" }
            function tuned(s) {
                const saved = Backend.settings.groundTuning || {}, v = Number(saved[s.key])
                return saved[s.key] !== undefined && isFinite(v) ? Math.max(s.from, Math.min(s.to, v)) : s.default
            }
            function setTuning(key, value) {
                const t = Object.assign({}, Backend.settings.groundTuning)
                t[key] = value
                Backend.settings.groundTuning = t
            }
            function pickGround(value) {  // a preset: its own colours again
                Backend.settings.groundColors = value
                const t = Object.assign({}, Backend.settings.groundTuning)
                for (const k of ["hue1", "hue2", "hue3", "hue4"]) delete t[k]
                Backend.settings.groundTuning = t
                sc.appRoot.sound("key")
            }
            function fmt(s, v) {
                if (s.unit === "°") return Math.round(v) + "°"
                if (s.unit === "%") return (s.from < 0 && v > 0 ? "+" : "") + Math.round(v * 100) + "%"
                return v.toFixed(2).replace(/0$/, "") + "×"
            }
            // In Glass the cartridges' "same as the theme color" has no theme colour to show:
            // its colour stands for it.
            readonly property string card: Backend.theme.glassy && Backend.settings.cardColor === "same"
                                           ? Backend.theme.cardValue : Backend.settings.cardColor
            // What the choices below look like, live.
            LookPreview { width: parent.width }
            Label_ { text: "Look" }
            Column {
                width: parent.width
                spacing: Ui.gapXS  // the same gap as the font rows
                property string openKey: ""
                Choice {
                    label: "Theme"
                    key: "look"
                    choices: ["glass", "plastic"]
                    names: ({ glass: "Glass", plastic: "Plastic" })
                    current: Backend.theme.look
                }
                // Dark or light, whatever the colour (styled like the rows around it).
                Rectangle {
                    width: parent.width
                    height: Ui.controlHeight
                    radius: Ui.radiusSmall
                    color: Qt.alpha(sc.pal.panelHover, 0.5)
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Ui.gapM
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Mode"
                        color: sc.pal.panelTextDim
                        font.family: Ui.fontText
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textCaption
                    }
                    CSegmented {
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 170
                        height: parent.height - 6
                        Accessible.name: "Mode"
                        value: Backend.theme.dark ? "dark" : "light"
                        options: [{ value: "dark", text: "Dark" }, { value: "light", text: "Light" }]
                        onPicked: (v) => { Backend.settings.themeMode = v; sc.appRoot.sound("key") }
                    }
                }
                Choice {
                    visible: Backend.theme.glassy
                    label: "Background"
                    key: "background"
                    choices: ["mesh", "rays", "iris", "topo", "still"]
                    names: ({ mesh: "Mesh", rays: "Underwater", iris: "Holographic", topo: "Contours", still: "Still" })
                    current: look.style
                }
            }
            // Glass: the ground's colours (presets), and Advanced.
            Column {
                visible: Backend.theme.glassy
                width: parent.width
                spacing: Ui.gapM
                Label_ { text: "Background Colors  ·  " + (Backend.theme.groundCustom ? "Custom" : look.groundName(Backend.theme.groundColors)) }
                Row {
                    spacing: Ui.gapS
                    Repeater {
                        model: Backend.theme.groundOptions
                        delegate: ColorChip {
                            required property var modelData
                            size: look.chipSize
                            label: "Background colors: " + modelData.text
                            colors: modelData.colors
                            selected: !Backend.theme.groundCustom && Backend.theme.groundColors === modelData.value
                            onPicked: look.pickGround(modelData.value)
                        }
                    }
                    ColorChip {  // the colours Advanced made
                        visible: Backend.theme.groundCustom
                        size: look.chipSize
                        label: "Background colors: custom"
                        colors: Backend.theme.groundNow
                        selected: true
                    }
                }
                // Blur, for every style (not part of Advanced or its Reset).
                SliderRow {
                    label: "Blur"
                    value: Math.round(Backend.settings.groundBlur * 100) + "%"
                    CSlider {
                        anchors.fill: parent
                        from: 0
                        to: 1
                        stepSize: 0.01
                        snapMode: QQC2.Slider.SnapAlways
                        value: Backend.settings.groundBlur
                        Accessible.name: "Background blur"
                        onMoved: Backend.settings.groundBlur = Math.round(value * 100) / 100
                    }
                }
                // Advanced: each colour of the background (as many as the style uses), then every
                // other variable of its drawing. All of them show live.
                Column {
                    id: adv
                    width: parent.width
                    spacing: Ui.gapXS
                    property bool open: false
                    readonly property bool customized: Object.keys(Backend.settings.groundTuning || {}).length > 0
                    FoldHead {
                        title: "Advanced"
                        summary: adv.customized ? "Customized" : "Default"
                        open: adv.open
                        onClicked: adv.open = !adv.open
                    }
                    Column {
                        visible: adv.open
                        width: parent.width
                        spacing: 2
                        topPadding: Ui.gapXS
                        Repeater {
                            model: look.style === "still" ? 1 : 4
                            delegate: SliderRow {
                                id: hueRow
                                required property int index
                                readonly property real hue: ((Backend.theme.ground.hues[index] || 0) % 360 + 360) % 360
                                label: look.style === "still" ? "Color" : "Color " + (index + 1)
                                value: Math.round(hue) + "°"
                                HueSlider {
                                    anchors.fill: parent
                                    track: Backend.theme.groundHueTracks[hueRow.index] || []
                                    swatch: Backend.theme.groundNow[hueRow.index] || "transparent"
                                    value: hueRow.hue
                                    Accessible.name: hueRow.label + " hue"
                                    onMoved: look.setTuning("hue" + (hueRow.index + 1), Math.round(value))
                                }
                            }
                        }
                        Repeater {
                            model: look.tuningSpec.filter(s => !s.styles.length || s.styles.indexOf(look.style) >= 0)
                            delegate: SliderRow {
                                id: tuneRow
                                required property var modelData
                                label: modelData.text
                                value: look.fmt(modelData, look.tuned(modelData))
                                CSlider {
                                    anchors.fill: parent
                                    from: tuneRow.modelData.from
                                    to: tuneRow.modelData.to
                                    stepSize: tuneRow.modelData.unit === "°" ? 5 : tuneRow.modelData.unit === "%" ? 0.01 : 0.05
                                    snapMode: QQC2.Slider.SnapAlways
                                    value: look.tuned(tuneRow.modelData)
                                    Accessible.name: tuneRow.modelData.text
                                    onMoved: look.setTuning(tuneRow.modelData.key, Math.round(value * 100) / 100)
                                }
                            }
                        }
                        Item {
                            width: parent.width
                            height: resetButton.height + Ui.gapXS
                            CButton {
                                id: resetButton
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                enabled: adv.customized
                                text: "Reset"
                                icon.name: "view-refresh-symbolic"
                                Accessible.name: "Reset the background's advanced settings"
                                onClicked: { Backend.settings.groundTuning = {}; sc.appRoot.sound("key") }
                            }
                        }
                    }
                }
            }
            // Plastic: the theme colour tints the look, in either mode.
            // Eight suggested colours and the colour picker. The colour never changes the mode.
            // (A colour that isn't one of the eight — picked, or saved before — shows in the
            // picker's chip.)
            Label_ { visible: !Backend.theme.glassy; text: "Theme Color  ·  " + look.nameOf(Backend.settings.hardware) }
            Row {
                visible: !Backend.theme.glassy
                spacing: Ui.gapS
                Repeater {
                    model: look.suggested
                    delegate: ColorChip {
                        required property var modelData
                        size: look.chipSize
                        label: "Theme color: " + modelData.text
                        plastic: modelData.color
                        selected: Backend.settings.hardware === modelData.value
                        onPicked: Backend.settings.hardware = modelData.value
                    }
                }
                ColorChip {
                    readonly property bool other: !look.isSuggested(Backend.settings.hardware)
                    size: look.chipSize
                    label: "Theme color: pick any color"
                    rainbow: !other
                    plastic: other ? Backend.theme.plasticOf(Backend.settings.hardware) : "transparent"
                    selected: other
                    onPicked: sc.appRoot.pickColor("hardware")
                }
            }
            // The cartridges, in either look.
            Label_ { text: "Cartridge Color  ·  " + (look.card === "same" ? "Same as the theme color"
                                                      : look.card === "auto" ? look.nameOf(Backend.theme.cardValue) + ", picked for you"
                                                      : look.nameOf(look.card)) }
            Row {
                spacing: Ui.gapS
                Repeater {
                    model: look.suggested
                    delegate: ColorChip {
                        required property var modelData
                        size: look.chipSize
                        label: "Cartridge color: " + modelData.text
                        plastic: modelData.color
                        selected: look.card === modelData.value
                        onPicked: Backend.settings.cardColor = modelData.value
                    }
                }
                ColorChip {
                    readonly property bool other: ["same", "auto"].indexOf(look.card) < 0 && !look.isSuggested(look.card)
                    size: look.chipSize
                    label: "Cartridge color: pick any color"
                    rainbow: !other
                    plastic: other ? Backend.theme.plasticOf(look.card) : "transparent"
                    selected: other
                    onPicked: sc.appRoot.pickColor("card")
                }
                // On, it stays on: the cartridges follow the suggested partner of the theme colour
                // (in Glass, of the background). Choosing a colour above turns it off; so does
                // choosing it again (the colour it picked stays).
                CButton {
                    readonly property bool on: Backend.settings.cardColor === "auto"
                    anchors.verticalCenter: parent.verticalCenter
                    height: look.chipSize + 2
                    kind: on ? "primary" : "plain"
                    text: "Pick for me"
                    icon.name: "sparkles"
                    Accessible.role: Accessible.CheckBox
                    Accessible.checked: on
                    Accessible.name: "Pick the cartridge color for me, to go with the " + (Backend.theme.glassy ? "background" : "theme color")
                    onClicked: {
                        Backend.settings.cardColor = on ? Backend.theme.cardValue : "auto"
                        sc.appRoot.sound("key")
                    }
                }
            }
            // Fonts: one row naming the fonts in use; choosing it unfolds the four kinds of text.
            Column {
                id: fonts
                width: parent.width
                spacing: Ui.gapXS
                property bool open: false
                readonly property var inUse: [Ui.fontLabels, Ui.fontTitles, Ui.fontButtons, Ui.fontText]
                                             .filter((f, i, all) => all.indexOf(f) === i)
                FoldHead {
                    title: "Fonts"
                    summary: fonts.inUse.join("  ·  ")
                    open: fonts.open
                    onClicked: fonts.open = !fonts.open
                }
                Column {
                    visible: fonts.open
                    width: parent.width
                    spacing: Ui.gapXS
                    property string openKey: "" // the kind of text whose choices are showing
                    Choice { label: "Labels"; key: "fontLabels"; choices: Ui.labelFonts; current: Ui.fontLabels }
                    Choice { label: "Game titles"; key: "fontTitles"; choices: Ui.titleFonts; current: Ui.fontTitles }
                    Choice { label: "Buttons"; key: "fontButtons"; choices: Ui.buttonFonts; current: Ui.fontButtons }
                    Choice { label: "Text"; key: "fontText"; choices: Ui.textFonts; current: Ui.fontText }
                }
            }
            // Card size is set on the library itself (App.qml: a bar with − and + over the games).
            FoldHead {
                title: "Adjust Card Size"
                arrow: "go-next-symbolic"
                Accessible.name: "Adjust card size, on the library"
                onClicked: sc.appRoot.adjustCardSize()
            }
            // Game View: what's behind a game's closer look.
            Label_ { text: "Game View" }
            Column {
                width: parent.width
                spacing: Ui.gapXS
                property string openKey: ""
                Choice {
                    label: "Background"
                    key: "gameBackground"
                    choices: ["blur", "backdrop"]
                    names: ({ blur: "Blur", backdrop: "Game Backdrop" })
                    current: Backend.settings.gameBackground === "blur" ? "blur" : "backdrop"
                }
                Note {
                    visible: Backend.settings.gameBackground !== "blur"
                    leftPadding: Ui.gapM
                    text: "If none is found, defaults to Blur for that game"
                }
            }
            Column {
                width: parent.width
                spacing: 2
                CSwitch {
                    width: parent.width
                    text: "Color uninstalled games"
                    hint: "Show the art of games you haven't installed in color, not greyed out"
                    checked: Backend.settings.colorUninstalled
                    onToggled: Backend.settings.colorUninstalled = checked
                }
                CSwitch {
                    width: parent.width
                    text: "Tilt cards on hover"
                    checked: Backend.settings.tiltEnabled
                    onToggled: Backend.settings.tiltEnabled = checked
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
            Label_ { text: "Shelves" }
            CSegmented {
                width: parent.width
                value: Backend.settings.storeLayout
                options: [
                    { value: "rows", text: "Rows" },
                    { value: "scroll", text: "Scroll Sideways" },
                ]
                onPicked: (v) => { Backend.settings.storeLayout = v; sc.appRoot.sound("key") }
            }
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
                                                : "Prices from GOG, Microsoft Store, EA and Battle.net too. Needs an IsThereAnyDeal key, in Accounts & Keys"
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
                purpose: "Shows Steam-owned games not found in local files. Your Steam game details must be public. Any domain name works on Steam's form, e.g. localhost."
                getUrl: "https://steamcommunity.com/dev/apikey"
            }
            KeyRow {
                width: parent.width
                service: "itad"
                title: "IsThereAnyDeal"
                purpose: "Adds prices from GOG, Microsoft Store, EA and Battle.net. Register an app on IsThereAnyDeal to get a key."
                getUrl: "https://isthereanydeal.com/apps/my/"
            }
            Note {
                text: "Keys are saved in " + (Qt.platform.os === "windows" ? "Windows Credential Manager" : "your system keyring") + " and sent to the service named above. <a href=\"https://steamcommunity.com/dev/apikey\">Revoke your Steam key</a>."
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
                    text: "Repeat Tutorial"
                    icon.name: "help-about-symbolic"
                    onClicked: sc.appRoot.repeatTour()
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
                hint: "Shows library or store activity on Discord while Carthage is active"
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
            Row {
                width: parent.width
                spacing: Ui.gapS
                CButton {
                    width: (parent.width - Ui.gapS) / 2
                    text: "Send Feedback"
                    icon.name: "dialog-messages-symbolic"
                    onClicked: sc.appRoot.sendFeedback()
                }
                CButton {
                    width: (parent.width - Ui.gapS) / 2
                    text: "Copy Diagnostics"
                    icon.name: "tools-symbolic"
                    Accessible.description: "Copies a report about Carthage and this PC, for a bug report"
                    onClicked: sc.appRoot.notify(Backend.copyDiagnostics()
                        ? "Diagnostics copied. Paste them into your bug report."
                        : "Couldn't make the diagnostics. Try again, or send the log from " + (Qt.platform.os === "windows"
                          ? "%LOCALAPPDATA%\\Carthage" : "~/.cache/carthage") + ".")
                }
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
