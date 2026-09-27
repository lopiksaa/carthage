// "Change Art…": every square image SteamGridDB has for a game, to pick from.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

CDialog {
    id: picker

    property string gameId
    property string gameTitle
    property string kind: "square"
    property Item appRoot
    property string repositionAfter: ""
    property var results: []        // SteamGridDB search results
    property string matchName: ""   // the SteamGridDB game the options come from, if searched
    property var items: []
    property string state_: "loading" // loading | ready | error
    property string error: ""

    function openFor(gid, title) {
        gameId = gid
        gameTitle = title
        kind = "square"
        results = []
        matchName = ""
        searchField.text = ""
        open()
        load()
    }
    function searchText(t) {  // demo harness
        searchField.text = t
    }
    function load() {
        items = []
        if (!Backend.artPicker) { error = "Art isn't available here (the demo library has no art source)."; state_ = "error"; return }
        state_ = "loading"
        Backend.artPicker.loadCandidates(gameId, kind)
    }

    maxWidth: 720
    readonly property real contentNeeded: tabs.y + tabs.height + Ui.gapM
                                          + (state_ === "ready" ? grid.contentHeight : 160) + 2 * Ui.gapXL
    height: Math.min(620, parent ? parent.height - 48 : 620, contentNeeded)

    Connections {
        target: Backend.artPicker
        function onCandidatesReady(gid, list) {
            if (gid !== picker.gameId) return
            picker.items = list
            picker.state_ = "ready"
        }
        function onSearchResults(term, list) {
            if (term === searchField.text.trim()) picker.results = list
        }
        function onChosen(gid) {
            if (gid === picker.repositionAfter) {
                picker.repositionAfter = ""
                picker.appRoot.repositionArt(gid, picker.gameTitle)
            }
        }
        function onChoiceFailed(gid, message) {
            if (gid !== picker.gameId) return
            picker.error = message
            picker.state_ = "error"
        }
    }

    FileDialog {
        id: fileDialog
        title: "Choose an image for " + picker.gameTitle
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)"]
        onAccepted: {
            const path = Backend.localPath(selectedFile)
            picker.repositionAfter = picker.gameId
            Backend.artPicker.chooseFile(picker.gameId, path)
            picker.close()
        }
    }

    contentItem: Item {
        Row {
            id: top
            width: parent.width
            spacing: Ui.gapM
            Column {
                width: parent.width - reset.width - close.width - fromFile.width - 30
                Text {
                    text: "Choose Art"
                    color: picker.pal.panelText
                    font.family: "Nunito"
                    font.weight: Font.Black
                    font.pixelSize: Ui.textTitle
                }
                Text {
                    width: parent.width
                    text: picker.gameTitle + " · from SteamGridDB" + (picker.matchName ? " (" + picker.matchName + ")" : "")
                    color: picker.pal.panelTextDim
                    font.family: "Nunito"
                    font.pixelSize: Ui.textBody
                    elide: Text.ElideRight
                }
            }
            CButton {
                id: fromFile
                text: "From File…"
                icon.name: "document-open-symbolic"
                onClicked: fileDialog.open()
            }
            CButton {
                id: reset
                text: "Automatic"
                icon.name: "view-refresh-symbolic"
                onClicked: {
                    Backend.artPicker.reset(picker.gameId)
                    picker.close()
                }
            }
            CButton {
                id: close
                kind: "ghost"
                icon.name: "window-close-symbolic"
                Accessible.name: "Close"
                onClicked: picker.close()
            }
        }

        QQC2.TextField {
            id: searchField
            anchors.top: top.bottom
            anchors.topMargin: 12
            width: parent.width
            height: Ui.controlHeight
            leftPadding: 34
            placeholderText: "Search SteamGridDB for another game…"
            placeholderTextColor: picker.pal.panelTextDim
            color: picker.pal.panelText
            font.family: "Nunito"
            font.weight: Font.DemiBold
            font.pixelSize: Ui.textBody
            selectByMouse: true
            onTextChanged: searchDelay.restart()
            onAccepted: searchDelay.triggered()
            background: Rectangle {
                radius: height / 2
                color: picker.pal.panelHover
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? Backend.theme.accent.accent : picker.pal.panelBorder
            }
            CIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: "search-symbolic"
                isMask: true
                color: picker.pal.panelTextDim
            }
            Timer {
                id: searchDelay
                interval: 350
                onTriggered: {
                    const t = searchField.text.trim()
                    if (t.length >= 2) Backend.artPicker.searchGames(t)
                    else picker.results = []
                }
            }
        }
        Flow {
            id: resultsRow
            visible: picker.results.length > 0
            anchors.top: searchField.bottom
            anchors.topMargin: 8
            width: parent.width
            spacing: Ui.gapS
            Repeater {
                model: picker.results
                delegate: CButton {
                    required property var modelData
                    height: 30
                    text: modelData.name + (modelData.year ? " (" + modelData.year + ")" : "")
                    onClicked: {
                        Backend.artPicker.useSgdbGame(picker.gameId, modelData.id)
                        picker.matchName = modelData.name
                        picker.results = []
                        searchField.text = ""
                        picker.load()
                    }
                }
            }
        }

        CSegmented {
            id: tabs
            anchors.top: resultsRow.visible ? resultsRow.bottom : searchField.bottom
            anchors.topMargin: 12
            width: parent.width
            value: picker.kind
            options: [
                { value: "square", text: "Square" },
                { value: "portrait", text: "Portrait" },
                { value: "wide", text: "Wide" },
                { value: "banner", text: "Banners" },
            ]
            onPicked: (v) => {
                picker.kind = v
                picker.load()
            }
        }

        Text {
            visible: picker.state_ !== "ready"
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            text: picker.state_ === "loading" ? "Looking for art…" : picker.error
            color: picker.pal.panelTextDim
            font.family: "Nunito"
            font.weight: Font.Bold
            font.pixelSize: Ui.textLead
            wrapMode: Text.Wrap
        }

        GridView {
            id: grid
            visible: picker.state_ === "ready"
            anchors.top: tabs.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            model: picker.items
            readonly property real ratio: picker.kind === "portrait" ? 1.5 : picker.kind === "wide" ? 0.47
                                        : picker.kind === "banner" ? 0.32 : 1
            readonly property int cols: Math.max(2, Math.floor(width / (picker.kind === "wide" || picker.kind === "banner" ? 280 : 150)))
            cellWidth: Math.floor(width / cols)
            cellHeight: Math.round(cellWidth * ratio)
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: CScrollBar { ink: Backend.theme.p.panelText }

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Ui.radiusMedium
                    color: picker.pal.panelHover
                    clip: true
                    scale: hh.hovered ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    border.width: hh.hovered ? 3 : 0
                    border.color: Backend.theme.accent.accent

                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: cell.modelData.thumb
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                    CIcon {
                        visible: parent.children[0].status !== Image.Ready
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "image-symbolic"
                        isMask: true
                        color: picker.pal.panelTextDim
                    }
                    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                    // A MouseArea (not a TapHandler) so the click is consumed here and never
                    // reaches the cards underneath the picker.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!cell.modelData.square) picker.repositionAfter = picker.gameId
                            Backend.artPicker.choose(picker.gameId, cell.modelData.url)
                            picker.close()
                        }
                    }
                }
            }
        }
    }
}
