// Links to where people look a game up.
//   GameLinks { appid: 1245620; title: "Elden Ring"; website: info.website; metacriticUrl: … }
import QtQuick
import Carthage

Column {
    id: gl

    property int appid: 0          // Steam app id, 0 for games that aren't on Steam
    property string title
    property string website
    property string metacriticUrl

    readonly property var links: {
        const q = encodeURIComponent(title)
        const out = []
        if (website) out.push({ text: "Official Website", url: website })
        if (appid && Qt.platform.os === "linux")
            out.push({ text: "ProtonDB", url: "https://www.protondb.com/app/" + appid })
        out.push({ text: "PCGamingWiki", url: appid ? "https://www.pcgamingwiki.com/api/appid.php?appid=" + appid
                                                     : "https://www.pcgamingwiki.com/w/index.php?search=" + q })
        if (appid) out.push({ text: "SteamDB", url: "https://steamdb.info/app/" + appid + "/" })
        if (metacriticUrl) out.push({ text: "Metacritic", url: metacriticUrl })
        return out
    }

    visible: title !== "" || appid > 0
    spacing: Ui.gapS

    Text {
        text: "MORE ABOUT THIS GAME"
        color: Ui.onScrimDim
        font.family: Ui.fontText
        font.weight: Font.Black
        font.pixelSize: Ui.textCaption
        font.letterSpacing: 2
    }
    Flow {
        width: parent.width
        spacing: Ui.gapS
        Repeater {
            model: gl.links
            delegate: Rectangle {
                id: tag
                required property var modelData
                height: 30
                width: tagRow.implicitWidth + 2 * Ui.gapM
                radius: 15
                color: tagHover.hovered ? Ui.scrimControlHover : Ui.scrimControl
                Accessible.role: Accessible.Link
                Accessible.name: modelData.text
                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tag.modelData.text
                        color: Ui.onScrim
                        font.family: Ui.fontText
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textCaption
                    }
                    Text {  // leaves Carthage (the same mark as "Get a free key ↗")
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↗"
                        color: Ui.onScrimDim
                        font.family: Ui.fontText
                        font.weight: Font.Bold
                        font.pixelSize: Ui.textCaption
                    }
                }
                HoverHandler { id: tagHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Backend.openUrl(tag.modelData.url) }
            }
        }
    }
}
