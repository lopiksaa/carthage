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
    property string emptyAction  // a button under the empty state
    property string emptyIcon: "bookmark"
    signal emptyActionTriggered()
    readonly property int count: shelf.count

    contentHeight: shelf.height + 2 * Ui.spacingLarge
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: CScrollBar {}
    WheelAccel { flickable: page; step: 110 }
    AutoScroll { flickable: page }

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
        // Centered on the page, not on the (empty, nearly zero-height) content: that put the
        // icon above the top edge and the text against the bar.
        width: page.width - 80
        x: Math.round((page.width - width) / 2)
        y: Math.max(Ui.spacingLarge, Math.round((page.height - page.bottomMargin - height) / 2))
        iconName: page.emptyIcon
        text: page.emptyText
        explanation: page.emptyHint
        actionText: page.emptyAction
        onAction: page.emptyActionTriggered()
    }
}
