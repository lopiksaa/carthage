// The sidebar (layout concept): the console's side panel, with the library's lists and
// sources, the store's pages and Settings. The burger folds it to a strip of icons; every
// icon keeps its place in both states, so nothing jumps.
//   Sidebar { page: app.page; onNavigate: (p) => …; onSearchRequested: … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: bar

    property Item appRoot
    property string page: "library:all"
    readonly property bool collapsed: Backend.settings.sidebarCollapsed
    function toggle() { Backend.settings.sidebarCollapsed = !collapsed }
    signal navigate(string page)
    signal searchRequested()

    readonly property var pal: Backend.theme.p
    readonly property real wideW: 232
    readonly property real narrowW: 60
    readonly property real side: 10      // the entries' margin from both edges
    readonly property real iconX: 11     // the icon inside an entry (centered when folded)
    readonly property real topH: 52      // the top row, level with the pages' title row

    // The pages move to the new width at once (one layout, not one per frame); the panel
    // itself slides over them.
    readonly property real layoutWidth: collapsed ? narrowW : wideW
    width: layoutWidth
    Behavior on width { NumberAnimation { duration: 170 * Backend.motion; easing.type: Easing.OutCubic } }

    Plastic { anchors.fill: parent }
    Rectangle { // the seam against the tray
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: bar.pal.dockSeam
    }
    // The panel's shadow on the tray (light from the top left).
    Rectangle {
        x: parent.width
        width: 12
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.32 : 0.16) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // One entry: an icon (a UI icon or a launcher's mark), a name and a count.
    component Entry: QQC2.AbstractButton {
        id: entry
        property string target
        property string iconName
        property string launcher      // a launcher key: its mark instead of iconName
        property int count: -1
        readonly property bool current: target !== "" && bar.page === target
        x: bar.side
        width: bar.width - 2 * bar.side
        height: 34
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.Button
        Accessible.name: text + (count > 0 ? ", " + count : "")
        onClicked: if (target) bar.navigate(target)
        QQC2.ToolTip.visible: bar.collapsed && hovered
        QQC2.ToolTip.text: text
        QQC2.ToolTip.delay: 300
        // Lit when chosen or pointed at; a little softer otherwise.
        readonly property color ink: current || hovered ? bar.pal.dockText : Qt.alpha(bar.pal.dockText, 0.78)
        // The chosen page is a key pressed into the panel (shaded at the top, caught by the light
        // at the bottom) with a lit mark at its left; hover only lightens.
        background: Item {
            Rectangle {
                anchors.fill: parent
                radius: Ui.radiusSmall
                color: entry.current ? Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.30 : 0.16)
                     : entry.down ? Qt.rgba(0, 0, 0, 0.14)
                     : entry.hovered ? Qt.alpha(bar.pal.dockText, 0.07) : "transparent"
                border.width: entry.visualFocus ? 2 : 0
                border.color: Ui.focusColor
            }
            Rectangle {  // the shade under the top edge
                visible: entry.current
                x: 4
                y: 0
                width: parent.width - 8
                height: 2
                radius: 1
                color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.35 : 0.18)
            }
            Rectangle {  // the light on the bottom lip
                visible: entry.current
                x: 6
                anchors.bottom: parent.bottom
                width: parent.width - 12
                height: 1
                color: Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.10 : 0.45)
            }
            Rectangle {  // the lit mark
                visible: entry.current
                x: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 16
                radius: 1.5
                color: Backend.theme.accent.accent
                Rectangle {  // its glow
                    anchors.centerIn: parent
                    width: 9
                    height: 22
                    radius: 4.5
                    color: Qt.alpha(Backend.theme.accent.accent, 0.25)
                    z: -1
                }
            }
        }
        contentItem: Item {
            Image {
                id: entryIcon
                x: bar.iconX
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                sourceSize: Qt.size(Math.ceil(18 * Screen.devicePixelRatio), Math.ceil(18 * Screen.devicePixelRatio))
                readonly property string ink: entry.ink.toString().replace("#", "")
                source: entry.launcher ? "image://gc/launcher/" + entry.launcher + "/" + ink
                                       : "image://gc/icon/" + entry.iconName + "/" + ink
            }
            Text {
                opacity: bar.collapsed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 120 * Backend.motion } }
                visible: opacity > 0
                anchors.left: entryIcon.right
                anchors.leftMargin: 12
                anchors.right: countText.left
                anchors.rightMargin: Ui.gapS
                anchors.verticalCenter: parent.verticalCenter
                text: entry.text
                elide: Text.ElideRight
                color: entry.ink
                font.family: Ui.fontText
                font.weight: entry.current ? Font.Bold : Font.Medium
                font.pixelSize: Ui.textBody
            }
            Text {
                id: countText
                opacity: bar.collapsed ? 0 : 1
                visible: opacity > 0 && entry.count > 0
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: entry.count
                color: bar.pal.dockTextDim
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
                font.features: { "tnum": 1 }
            }
        }
    }
    // A group's name; folded, a short line instead.
    component Heading: Item {
        property string text
        width: bar.width
        height: bar.collapsed ? 15 : 30
        Behavior on height { NumberAnimation { duration: 170 * Backend.motion; easing.type: Easing.OutCubic } }
        Text {
            opacity: bar.collapsed ? 0 : 1
            visible: opacity > 0
            x: bar.side + bar.iconX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: parent.text
            color: bar.pal.dockTextDim
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textCaption - 1
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
        }
        Rectangle {
            opacity: bar.collapsed ? 1 : 0
            visible: opacity > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 1
            color: Qt.alpha(bar.pal.dockText, 0.22)
        }
    }

    // The top row: the burger (always in the same place) and the name.
    Item {
        id: top
        width: parent.width
        height: bar.topH
        CButton {
            id: burger
            x: bar.side
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 36
            kind: "ghost"
            tint: bar.pal.dockText
            icon.name: "application-menu"
            Accessible.name: bar.collapsed ? "Show the sidebar" : "Fold the sidebar"
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: (bar.collapsed ? "Show the sidebar" : "Fold the sidebar") + " (Ctrl+B)"
            QQC2.ToolTip.delay: 500
            onClicked: bar.toggle()
        }
        Row {
            opacity: bar.collapsed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 * Backend.motion } }
            visible: opacity > 0
            x: burger.x + burger.width + 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            CIcon {  // the glyph is 16 × 22: drawn at its own proportions
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 18
                source: "carthage"
                color: bar.pal.dockText
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CARTHAGE"
                color: bar.pal.dockText
                font.family: Ui.fontLabels
                font.weight: Font.Black
                font.pixelSize: Ui.textBody + 1
                font.letterSpacing: 3
            }
        }
    }

    Flickable {
        id: scroller
        anchors.top: top.bottom
        anchors.bottom: bottomRow.top
        width: parent.width
        contentHeight: content.height + Ui.gapM
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar { ink: bar.pal.dockText }

        Column {
            id: content
            width: scroller.width
            spacing: 2

            // Search looks like a field: a slot cut into the panel, with its shortcut.
            QQC2.AbstractButton {
                id: searchKey
                readonly property bool current: bar.page === "search"
                x: bar.side
                width: bar.width - 2 * bar.side
                height: 34
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.Button
                Accessible.name: "Search your games and the stores"
                onClicked: bar.searchRequested()
                QQC2.ToolTip.visible: bar.collapsed && hovered
                QQC2.ToolTip.text: "Search (Ctrl+F)"
                QQC2.ToolTip.delay: 300
                background: Rectangle {
                    radius: Ui.radiusSmall
                    color: Qt.rgba(0, 0, 0, searchKey.hovered ? (Backend.theme.dark ? 0.32 : 0.16) : (Backend.theme.dark ? 0.24 : 0.11))
                    border.width: searchKey.visualFocus || searchKey.current ? 2 : 1
                    border.color: searchKey.visualFocus ? Ui.focusColor
                                : searchKey.current ? Backend.theme.accent.accent
                                : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.35 : 0.12)
                    Rectangle {  // the light on the bottom lip
                        x: 6
                        anchors.bottom: parent.bottom
                        width: parent.width - 12
                        height: 1
                        color: Qt.rgba(1, 1, 1, Backend.theme.dark ? 0.08 : 0.5)
                    }
                }
                contentItem: Item {
                    CIcon {
                        id: searchIcon
                        x: bar.iconX
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: "search"
                        color: Qt.alpha(bar.pal.dockText, 0.8)
                    }
                    Text {
                        opacity: bar.collapsed ? 0 : 1
                        visible: opacity > 0
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search"
                        color: Qt.alpha(bar.pal.dockText, 0.6)
                        font.family: Ui.fontText
                        font.weight: Font.Medium
                        font.pixelSize: Ui.textBody
                    }
                    Rectangle {  // the shortcut's keycap
                        opacity: bar.collapsed ? 0 : 1
                        visible: opacity > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: capText.implicitWidth + 10
                        height: 18
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(bar.pal.dockText, 0.22)
                        Text {
                            id: capText
                            anchors.centerIn: parent
                            text: "Ctrl F"
                            color: Qt.alpha(bar.pal.dockText, 0.55)
                            font.family: Ui.fontText
                            font.weight: Font.Bold
                            font.pixelSize: Ui.textCaption - 1
                        }
                    }
                }
            }
            Item { width: 1; height: 4 }

            Heading { text: "Library" }
            Entry { text: "All Games"; iconName: "view-grid"; target: "library:all" }
            Entry {
                text: "Play Next"
                iconName: "bookmark"
                target: "library:playnext"
                count: Backend.playNext.count + Backend.playNextStore.length
            }
            Entry { text: "Favorites"; iconName: "starred"; target: "library:favorites"; count: Backend.favoritesList.count }
            Entry {
                text: "New List"
                iconName: "list-add"
                onClicked: bar.appRoot.notify("Your own lists come next (this is the layout concept).")
            }

            Heading { text: "Sources" }
            Repeater {
                model: Backend.games.launchers
                delegate: Entry {
                    required property var modelData
                    text: modelData.text
                    launcher: modelData.value.slice(7)  // "source:steam" → steam
                    target: "library:" + modelData.value
                    count: modelData.count || 0
                }
            }

            Heading { text: "Store" }
            Entry { text: "Discover"; iconName: "internet-services"; target: "store:discover" }
            Entry { text: "Deals"; iconName: "shopping-bag"; target: "store:deals" }
            Entry { text: "Free Now"; iconName: "tag"; target: "store:free" }
            Entry { text: "Genres"; iconName: "view-list-icons"; target: "store:genres" }
            Entry { text: "Wishlist"; iconName: "bookmark-filled"; target: "store:wishlist" }
        }
    }

    // Settings, apart at the bottom.
    Item {
        id: bottomRow
        anchors.bottom: parent.bottom
        width: parent.width
        height: 34 + 2 * Ui.gapS + 1
        Rectangle {
            x: bar.side
            width: parent.width - 2 * bar.side
            height: 1
            color: Qt.alpha(bar.pal.dockText, 0.14)
        }
        Entry {
            y: Ui.gapS + 1
            text: "Settings"
            iconName: "configure"
            target: "settings"
        }
    }
}
