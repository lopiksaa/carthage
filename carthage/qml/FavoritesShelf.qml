// The favorites shelf above the library. Empty, it's a drop zone.
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
                item.leftMargin = Qt.binding(() => fs.tray.leftMargin)
                item.rightMargin = Qt.binding(() => fs.tray.rightMargin)
                item.interactive = Qt.binding(() => item.contentWidth > item.width)
            }
        }
        readonly property var shelfView: shelfLoader.item || emptyShelf
        QtObject { id: emptyShelf; readonly property int count: 0; function cellFor(g) { return null } }

        Item {
            visible: zone.shelfView.count === 0
            x: fs.leftX
            width: fs.rightX - fs.leftX
            height: parent.height
            Shape {
                id: dash
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
                        font.family: Ui.fontText
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textBody
                    }
                }
                Text {
                    visible: !fs.dragging
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "or right-click one › Add to Favorites"
                    color: fs.pal.trayTextDim
                    font.family: Ui.fontText
                    font.pixelSize: Ui.textCaption
                }
            }
        }
    }

    // Always there, so the layout never shifts under a carried cartridge.
    EngravedLabel {
        x: fs.leftX
        text: "All Games"
    }
}
