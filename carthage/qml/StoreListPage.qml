// A store page made from a list of store games (sidebar layout concept): Deals, Free Now.
// Cartridges in a grid, with a note on where the games come from.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

GridView {
    id: grid

    property Item appRoot
    property Item tray      // the page grid: the library tray's margins and columns
    property var items: []
    property string note
    property string emptyText
    readonly property real cardW: Backend.settings.cardWidth

    signal chosen(var item, Item cart, var siblings)
    // Load More under the cartridges (when the page can fetch the next ones).
    property bool canLoadMore: false
    property bool loadingMore: false
    signal loadMore()
    footer: Item {
        visible: grid.canLoadMore || grid.loadingMore
        width: grid.width - grid.leftMargin - grid.rightMargin
        height: visible ? 72 : 0
        CButton {
            anchors.centerIn: parent
            enabled: !grid.loadingMore
            text: grid.loadingMore ? "Loading…" : "Load More"
            onClicked: grid.loadMore()
        }
    }

    leftMargin: tray.leftMargin
    rightMargin: tray.rightMargin
    topMargin: Ui.gapM
    bottomMargin: 120
    clip: true
    model: items
    cellWidth: tray.cellWidth
    cellHeight: cardW * Backend.theme.ratio + 90
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: CScrollBar {}
    WheelAccel { flickable: grid; step: grid.cellHeight * 0.34 }

    header: Text {
        visible: grid.note !== ""
        width: grid.width - grid.leftMargin - grid.rightMargin
        height: visible ? implicitHeight + Ui.gapL : 0
        topPadding: Ui.gapM
        text: grid.note
        wrapMode: Text.Wrap
        color: Backend.theme.p.trayTextDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textBody
    }
    delegate: Item {
        required property var modelData
        width: grid.cellWidth
        height: grid.cellHeight
        StoreCard {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            item: modelData
            cardW: grid.cardW
            appRoot: grid.appRoot
            onChosen: (it, cart) => grid.chosen(it, cart, grid.items)
        }
    }
    CPlaceholder {
        visible: grid.count === 0
        // On the view, not the (empty) content, which would put it against the top.
        parent: grid
        anchors.centerIn: parent
        width: grid.width - 80
        iconName: "view-refresh"
        text: grid.emptyText
    }
}
