// A library list as a page (sidebar layout concept): Play Next, Favorites, later the user's
// own lists. Owned games first, then store games (greyed, with a bag), in the tray's columns.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Flickable {
    id: page

    property Item tray      // the main tray, for the cartridge geometry
    property Item appRoot
    property var listModel
    property var storeItems: []
    property string emptyText
    property string emptyHint
    readonly property int count: shelf.count

    contentHeight: shelf.height + 2 * Ui.spacingLarge
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: CScrollBar {}
    WheelAccel { flickable: page; step: 110 }

    PlayNextShelf {
        id: shelf
        y: Ui.spacingLarge
        x: page.tray.leftMargin
        width: page.width - page.tray.leftMargin - page.tray.rightMargin
        asPage: true
        tray: page.tray
        appRoot: page.appRoot
        listModel: page.listModel
        storeItems: page.storeItems
    }

    CPlaceholder {
        visible: !shelf.visible
        anchors.centerIn: parent
        width: parent.width - 80
        iconName: "bookmark"
        text: page.emptyText
        explanation: page.emptyHint
    }
}
