// The favorites shelf at the top of the library: one row of recesses holding the
// cartridges moved there (drag one up from the tray, or right-click › Add to Favorites).
// Empty, it's an engraved drop zone that says how. While a cartridge is dragged over it,
// it lights up. Scrolls away with the tray.
import QtQuick
import QtQuick.Shapes
import Carthage

Column {
    id: fs

    property Item tray          // the main tray (for its geometry)
    property Item appRoot
    readonly property var shelf: zone.shelfView
    readonly property Item dropZone: zone
    readonly property var pal: Backend.theme.p
    readonly property bool searching: Backend.games.filterText !== ""
    readonly property bool hot: appRoot && appRoot.dragTarget === "favorites"
    readonly property bool dragging: appRoot && appRoot.dragging
    // The view places its header inside its left margin: positions below are in the tray's
    // coordinates, minus that.
    readonly property real leftX: tray.contentLeft - tray.leftMargin
    readonly property real rightX: tray.contentRight - tray.leftMargin

    // While searching, the shelf only shows if a favorite matches.
    visible: !searching || zone.shelfView.count > 0
    height: visible ? implicitHeight : 0
    topPadding: Ui.gapL
    spacing: Ui.gapS

    EngravedLabel {
        x: fs.leftX
        text: "Favorites"
    }

    Item {
        id: zone
        width: fs.width
        height: zone.shelfView.count > 0 ? fs.tray.cellHeight : 96

        // Lit while a cartridge is held over it.
        Rectangle {
            x: fs.leftX - Ui.gapS
            y: zone.shelfView.count > 0 ? Ui.gapS : 0
            width: fs.rightX - fs.leftX + 2 * Ui.gapS
            height: parent.height - (zone.shelfView.count > 0 ? 2 * Ui.gapS : 0)
            radius: Ui.radiusLarge
            color: Qt.alpha(Backend.theme.accent.accent, fs.hot ? 0.12 : 0)
            border.width: 2
            border.color: Qt.alpha(Backend.theme.accent.accent, fs.hot ? 0.9 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        // The shelf is itself a Tray (one row), loaded by URL: Tray already contains this
        // shelf, and QML won't let a type contain itself directly.
        Loader {
            id: shelfLoader
            x: -fs.tray.leftMargin
            width: fs.tray.width
            height: parent.height
            visible: zone.shelfView.count > 0
            Component.onCompleted: setSource(Qt.resolvedUrl("Tray.qml"), {
                shelf: true,
                trayModel: Backend.favorites,
                mainTray: fs.tray,
                appRoot: fs.appRoot,
            })
            onLoaded: {
                // Line the pockets up with the tray's columns.
                item.leftMargin = Qt.binding(() => fs.tray.leftMargin)
                item.rightMargin = Qt.binding(() => fs.tray.rightMargin)
                item.interactive = Qt.binding(() => item.contentWidth > item.width)
            }
        }
        readonly property var shelfView: shelfLoader.item || emptyShelf
        QtObject { id: emptyShelf; readonly property int count: 0; function cellFor(g) { return null } }

        // Empty: a recess in the tray waiting for cartridges, and how to fill it.
        Item {
            visible: zone.shelfView.count === 0
            x: fs.leftX
            width: fs.rightX - fs.leftX
            height: parent.height
            // A channel molded into the tray (Plastic), a ribbed rubber mat (Hi-Fi), or a
            // dashed outline (Classic).
            Shape {
                id: dash
                visible: Backend.theme.skin === "classic"
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: fs.hot ? "transparent" : fs.pal.engrave
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 4]
                    fillColor: "transparent"
                    PathRectangle {
                        x: 1
                        y: 1
                        width: dash.width - 2
                        height: dash.height - 2
                        radius: Ui.radiusLarge
                    }
                }
            }
            Rectangle {
                id: channel
                visible: !dash.visible
                anchors.fill: parent
                radius: Backend.theme.skin === "hifi" ? 6 : Ui.radiusLarge
                color: Backend.theme.skin === "hifi" ? "#161616" : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.28 : 0.08)
                clip: true
                Repeater { // rubber ribs
                    model: Backend.theme.skin === "hifi" ? Math.ceil(channel.width / 12) : 0
                    Rectangle {
                        required property int index
                        x: index * 12
                        width: 6
                        height: channel.height
                        color: "#1c1c1c"
                    }
                }
                Rectangle { // shade under the top edge: it's sunk into the surface
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.45 : 0.14) }
                        GradientStop { position: 0.25; color: "transparent" }
                    }
                }
            }
            Rectangle { // the lit lower rim of the recess (light from the top-left)
                visible: channel.visible
                anchors.left: channel.left
                anchors.right: channel.right
                anchors.leftMargin: channel.radius
                anchors.rightMargin: channel.radius
                anchors.top: channel.bottom
                height: 1
                color: fs.pal.engraveHi
            }
            Column {
                anchors.centerIn: parent
                spacing: 4
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Ui.gapS
                    CIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: "starred-symbolic"
                        isMask: true
                        color: fs.hot ? Backend.theme.accent.accent : fs.pal.trayTextDim
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: fs.hot ? "Drop it here" : "Drag a cartridge here to keep it close"
                        color: fs.hot ? fs.pal.trayText : fs.pal.trayTextDim
                        font.family: "Nunito"
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textBody
                    }
                }
                Text {
                    visible: !fs.dragging
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "or right-click one › Add to Favorites"
                    color: fs.pal.trayTextDim
                    font.family: "Nunito"
                    font.pixelSize: Ui.textCaption
                }
            }
        }
    }

    // Where the rest of the collection starts.
    // Always there, so the layout never shifts under a cartridge being carried.
    EngravedLabel {
        x: fs.leftX
        text: "All Games"
    }
}
