// Steam's user-review summary ("Very Positive · 92% of 12k") and the Metacritic score, plus
// optional extra chips (e.g. "51.8k playing now"). Store details from store.py.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Flow {
    id: badges

    property var info: ({})
    property var extraChips: []

    readonly property bool hasReviews: (info.reviews || "") !== ""
    readonly property bool hasMeta: (info.metacritic || 0) > 0
    visible: hasReviews || hasMeta || extraChips.length > 0
    spacing: Ui.gapS

    Rectangle {
        visible: badges.hasReviews
        height: 30
        width: revText.implicitWidth + 20
        radius: Ui.radiusSmall
        color: (badges.info.reviewPct || 0) >= 80 ? Qt.rgba(0.25, 0.55, 0.9, 0.35)
             : (badges.info.reviewPct || 0) >= 50 ? Qt.rgba(0.9, 0.7, 0.2, 0.3) : Qt.rgba(0.9, 0.3, 0.25, 0.3)
        // To the reviews on Steam.
        HoverHandler { cursorShape: badges.info.appid ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
            enabled: !!badges.info.appid
            onTapped: Backend.openUrl("https://store.steampowered.com/app/" + badges.info.appid + "/#app_reviews_hash")
        }
        Text {
            id: revText
            anchors.centerIn: parent
            text: (badges.info.reviews || "") + "  ·  " + badges.info.reviewPct + "% of " + (badges.info.reviewCount || "")
            color: Ui.onScrim
            font.family: "Nunito"
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
        }
    }
    Rectangle {
        visible: badges.hasMeta
        height: 30
        width: 30
        radius: Ui.radiusSmall
        color: (badges.info.metacritic || 0) >= 75 ? "#66cc33" : (badges.info.metacritic || 0) >= 50 ? "#ffcc33" : "#ff0000"
        Accessible.name: "Metacritic score " + (badges.info.metacritic || "")
        Text {
            anchors.centerIn: parent
            text: badges.info.metacritic || ""
            color: "#000000"
            font.family: "Nunito"
            font.weight: Font.Black
            font.pixelSize: Ui.textBody
        }
        QQC2.ToolTip.visible: mcHover.hovered
        QQC2.ToolTip.text: badges.info.metacriticUrl ? "Metacritic score · open the review" : "Metacritic score"
        HoverHandler { id: mcHover; cursorShape: badges.info.metacriticUrl ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
            enabled: !!badges.info.metacriticUrl
            onTapped: Backend.openUrl(badges.info.metacriticUrl)
        }
    }
    Repeater {
        model: badges.extraChips
        delegate: Rectangle {
            required property var modelData
            height: 30
            width: chipRow.implicitWidth + 20
            radius: Ui.radiusSmall
            color: Ui.scrimControl
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6
                Led { // a live light, like the dock's
                    visible: modelData.live === true
                    anchors.verticalCenter: parent.verticalCenter
                    size: 7
                    glow: false
                    color: Backend.theme.led.green
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    color: Ui.onScrim
                    font.family: "Nunito"
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textBody
                }
            }
        }
    }
}
