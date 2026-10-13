// The sidebar: the console's side panel, with the library's lists and sources, the store's
// pages and Settings. It slides out over the content from the right edge (App.qml); the top
// bar has the ≡, the name and the search field.
//   Sidebar { page: app.page; onNavigate: (p) => … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: bar
    objectName: "sidebar"  // for the test harness

    property Item appRoot
    property string page: "library:all"
    signal navigate(string page)

    readonly property var pal: Backend.theme.p
    readonly property real side: 10      // the entries' margin from both edges
    readonly property real iconX: 11     // the icon inside an entry

    width: 232

    // Glass: frosted over the library behind (live: it slides over it), tinted. Plastic: plastic.
    GlassPane {
        visible: Backend.theme.glassy
        anchors.fill: parent
        radius: 0
        behind: visible ? Ui.glassLayers : []
        track: Qt.point(bar.x, bar.y)
    }
    Rectangle {
        visible: Backend.theme.glassy
        anchors.fill: parent
        color: Backend.theme.glass.busyTint
    }
    Plastic { anchors.fill: parent; visible: !Backend.theme.glassy }
    Rectangle { // the seam against the tray, on its left (glass: the faint ring line)
        width: 1
        height: parent.height
        color: Backend.theme.glassy ? Backend.theme.glass.ring : bar.pal.dockSeam
    }
    // The panel's shadow on the tray, on the side facing it: soft and wide, fading out on a
    // curve (a short, strong linear one read as a hard dark band).
    Rectangle {
        id: sideShadow
        readonly property real strength: Backend.theme.dark ? 0.2 : 0.08
        function a(k) { return Qt.rgba(0, 0, 0, strength * k) }  // k: 1 at the panel, 0 far out
        x: -width
        width: 32
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: sideShadow.a(0) }
            GradientStop { position: 0.25; color: sideShadow.a(0.06) }
            GradientStop { position: 0.5; color: sideShadow.a(0.2) }
            GradientStop { position: 0.75; color: sideShadow.a(0.45) }
            GradientStop { position: 1.0; color: sideShadow.a(1) }
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
        // Lit when chosen or pointed at; a little softer otherwise.
        readonly property color ink: bar.pal.dockText  // full strength: ≥4.5:1 on every plastic (theme)
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
                visible: entry.count > 0
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
    // A group's name.
    component Heading: Item {
        property string text
        width: bar.width
        height: 30
        Text {
            x: bar.side + bar.iconX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: parent.text
            color: bar.pal.dockTextDim
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textCaption
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
        }
    }

    Flickable {
        id: scroller
        anchors.top: parent.top
        anchors.topMargin: Ui.gapM
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

            Heading { text: "Library" }
            Entry { text: "All Games"; iconName: "view-grid"; target: "library:all" }
            Entry {
                objectName: "tourPlayNext"  // (the first-run tour points at it)
                text: "Play Next"
                iconName: "bookmark"
                target: "library:playnext"
                count: Backend.playNext.count + Backend.playNextStore.length
            }
            Entry { text: "Favorites"; iconName: "starred"; target: "library:favorites"; count: Backend.favoritesList.count }
            Repeater {
                model: Backend.lists
                delegate: Entry {
                    required property var modelData
                    text: modelData.name
                    iconName: "view-list-icons"
                    target: "library:list:" + modelData.id
                    count: modelData.count
                }
            }
            Entry {
                text: "New List"
                iconName: "list-add"
                onClicked: { bar.appRoot.sidebarOpen = false; bar.appRoot.newList("") }
            }

            Heading { text: "Sources"; visible: Backend.games.launchers.length > 0 }
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
            objectName: "tourSettings"
            text: "Settings"
            iconName: "configure"
            target: "settings"
            UpdateDot {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
