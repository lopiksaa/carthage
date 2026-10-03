// The sidebar (layout concept): the console's side panel, with the library's lists and
// sources, the store's pages and Settings. It collapses to a strip of icons.
//   Sidebar { page: app.page; onNavigate: (p) => …; onSearchRequested: … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: bar

    property Item appRoot
    property string page: "library:all"
    property bool collapsed: false
    signal navigate(string page)
    signal searchRequested()

    readonly property var pal: Backend.theme.p
    readonly property real wideW: 236
    readonly property real narrowW: 68

    width: collapsed ? narrowW : wideW
    Behavior on width { NumberAnimation { duration: 170 * Backend.motion; easing.type: Easing.OutCubic } }
    clip: true

    Plastic { anchors.fill: parent }
    Rectangle { // the seam against the tray
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: bar.pal.dockSeam
    }

    // One entry: icon, name, count; the page it opens.
    component Entry: QQC2.AbstractButton {
        id: entry
        property string target
        property string iconName
        property int count: -1
        readonly property bool current: bar.page === target
        width: parent ? parent.width : 0
        height: 34
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.Button
        Accessible.name: text + (count >= 0 ? ", " + count : "")
        onClicked: if (target) bar.navigate(target)
        QQC2.ToolTip.visible: bar.collapsed && hovered
        QQC2.ToolTip.text: text
        QQC2.ToolTip.delay: 400
        background: Rectangle {
            radius: Ui.radiusSmall
            color: entry.current ? Backend.theme.accent.accent
                 : entry.hovered ? Qt.alpha(bar.pal.dockText, 0.1) : "transparent"
            border.width: entry.visualFocus ? 2 : 0
            border.color: Ui.focusColor
        }
        contentItem: Item {
            CIcon {
                id: entryIcon
                x: bar.collapsed ? Math.round((entry.width - width) / 2) : Ui.gapM
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: entry.iconName
                color: entry.current ? Backend.theme.accent.accentText : bar.pal.dockText
            }
            Text {
                visible: !bar.collapsed
                anchors.left: entryIcon.right
                anchors.leftMargin: Ui.gapM
                anchors.right: countText.left
                anchors.rightMargin: Ui.gapS
                anchors.verticalCenter: parent.verticalCenter
                text: entry.text
                elide: Text.ElideRight
                color: entry.current ? Backend.theme.accent.accentText : bar.pal.dockText
                font.family: Ui.fontText
                font.weight: entry.current ? Font.Bold : Font.DemiBold
                font.pixelSize: Ui.textBody
            }
            Text {
                id: countText
                visible: !bar.collapsed && entry.count >= 0
                anchors.right: parent.right
                anchors.rightMargin: Ui.gapM
                anchors.verticalCenter: parent.verticalCenter
                text: entry.count
                color: entry.current ? Backend.theme.accent.accentText : bar.pal.dockTextDim
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textCaption
            }
        }
    }
    component Heading: Text {
        visible: !bar.collapsed
        x: Ui.gapM
        topPadding: Ui.gapL
        bottomPadding: Ui.gapXS
        color: bar.pal.dockTextDim
        font.family: Ui.fontLabels
        font.weight: Font.Black
        font.pixelSize: Ui.textCaption
        font.letterSpacing: 2
        font.capitalization: Font.AllUppercase
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: Ui.gapM
        anchors.bottomMargin: settingsEntry.height + 2 * Ui.gapM
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: CScrollBar { ink: bar.pal.dockText }

        Column {
            id: content
            width: scroller.width
            spacing: 2

            // Logo and the collapse key.
            Item {
                width: parent.width
                height: 40
                Row {
                    visible: !bar.collapsed
                    anchors.verticalCenter: parent.verticalCenter
                    x: Ui.gapXS
                    spacing: Ui.gapS
                    CIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        source: "carthage"
                        color: bar.pal.dockText
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CARTHAGE"
                        color: bar.pal.dockText
                        font.family: Ui.fontLabels
                        font.weight: Font.Black
                        font.pixelSize: Ui.textLead
                        font.letterSpacing: 3.5
                    }
                }
                CButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 32
                    kind: "ghost"
                    tint: bar.pal.dockText
                    icon.name: bar.collapsed ? "go-next-symbolic" : "go-previous-symbolic"
                    Accessible.name: bar.collapsed ? "Show the sidebar" : "Hide the sidebar"
                    onClicked: bar.collapsed = !bar.collapsed
                }
            }

            Entry {
                text: "Search"
                iconName: "search"
                onClicked: bar.searchRequested()
            }

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
                    width: content.width
                    text: modelData.text
                    iconName: "applications-games"
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

    Entry {
        id: settingsEntry
        x: Ui.gapM
        width: parent.width - 2 * Ui.gapM
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Ui.gapM
        text: "Settings"
        iconName: "configure"
        target: "settings"
    }
}
