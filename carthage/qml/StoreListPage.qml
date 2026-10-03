// A store page made from a list of store games (sidebar layout concept): Deals, Free Now.
// Cartridges in a grid, with a note on where the games come from.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

GridView {
    id: grid

    property Item appRoot
    property var items: []
    property string note
    property string emptyText
    readonly property real cardW: Backend.settings.cardWidth

    signal chosen(var item, Item cart, var siblings)

    leftMargin: 24
    rightMargin: 24
    bottomMargin: 120
    clip: true
    model: items
    readonly property int cols: Math.max(1, Math.floor((width - 48) / (cardW + 40)))
    cellWidth: Math.floor((width - 48) / cols)
    cellHeight: cardW * Backend.theme.ratio + 90
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: CScrollBar {}
    WheelAccel { flickable: grid; step: grid.cellHeight * 0.34 }

    header: Text {
        visible: grid.note !== ""
        width: grid.width - 48
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
        anchors.centerIn: parent
        width: parent.width - 80
        iconName: "view-refresh"
        text: grid.emptyText
    }
}
