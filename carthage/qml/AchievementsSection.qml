// A Steam game's achievements on the closer look: progress, the icons (grey until unlocked)
// and the chosen one's details. Hidden for other launchers and games without achievements.
//   AchievementsSection { appid: 275850 }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Column {
    id: sec

    property int appid: 0
    property var result: ({})  // not `data`: every item already has one (its children)
    property bool loading: false
    property bool expanded: false
    property int chosen: -1   // the icon whose details show (-1: none yet)
    property int pointed: -1  // the icon under the pointer (previews its details)
    readonly property var items: result.items || []
    readonly property int shownCount: expanded ? items.length : Math.min(items.length, columns * 2)
    readonly property int iconSize: 44
    readonly property int columns: Math.max(1, Math.floor((width + Ui.gapS) / (iconSize + Ui.gapS)))
    readonly property var current: items[pointed >= 0 ? pointed : chosen] || null

    visible: appid > 0 && (loading || !!result.error || items.length > 0)
    spacing: Ui.gapS

    onAppidChanged: {
        result = ({})
        expanded = false
        chosen = -1
        pointed = -1
        if (appid > 0) {
            loading = true
            Backend.achievements.load(appid)
        }
    }
    Connections {
        target: Backend.achievements
        function onReady(id, result) {
            if (id !== sec.appid) return
            sec.result = result
            sec.loading = false
        }
    }

    function when(t) {
        return new Date(t * 1000).toLocaleDateString(Qt.locale(), "d MMM yyyy")
    }

    // Title, count and progress bar.
    Row {
        spacing: Ui.gapS
        Text {
            text: "Achievements"
            color: Ui.onScrim
            font.family: Ui.fontText
            font.weight: Font.Black
            font.pixelSize: Ui.textLead
        }
        Text {
            visible: sec.items.length > 0
            anchors.baseline: parent.children[0].baseline
            text: sec.result.unlocked + " of " + sec.result.total
            color: Ui.onScrimDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
        }
    }
    Rectangle {
        visible: sec.items.length > 0
        width: parent.width
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)
        Accessible.role: Accessible.ProgressBar
        Accessible.name: sec.result.unlocked + " of " + sec.result.total + " achievements unlocked"
        Rectangle {
            width: sec.result.total ? parent.width * sec.result.unlocked / sec.result.total : 0
            height: parent.height
            radius: parent.radius
            color: Backend.theme.accent.accent
        }
    }

    // Loading, or why there's nothing to show.
    Text {
        visible: sec.loading || !!sec.result.error
        width: parent.width
        text: sec.loading ? "Loading achievements…" : (sec.result.error || "")
        color: Ui.onScrimDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textBody
        wrapMode: Text.Wrap
    }

    // The icons: unlocked first (newest first), then locked (most common first).
    Grid {
        visible: sec.items.length > 0
        columns: sec.columns
        spacing: Ui.gapS
        Repeater {
            model: sec.shownCount
            delegate: QQC2.AbstractButton {
                id: ach
                required property int index
                readonly property var it: sec.items[index]
                width: sec.iconSize
                height: sec.iconSize
                padding: 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                onHoveredChanged: sec.pointed = hovered ? index : (sec.pointed === index ? -1 : sec.pointed)
                onClicked: sec.chosen = index
                Accessible.role: Accessible.Button
                Accessible.name: it.name + (it.unlocked ? ", unlocked" : ", locked")
                background: Rectangle {
                    radius: Ui.radiusSmall
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: ach.visualFocus || sec.chosen === ach.index ? 2 : 0
                    border.color: ach.visualFocus ? Ui.focusColor : Backend.theme.accent.accent
                }
                contentItem: Image {
                    source: ach.it.icon
                    sourceSize: Qt.size(sec.iconSize * 2, sec.iconSize * 2)
                    fillMode: Image.PreserveAspectFit
                    opacity: ach.it.unlocked ? 1 : 0.55
                    asynchronous: true
                    // Rounded like its frame (the icons are square pictures).
                    layer.enabled: true
                    layer.effect: RoundedMask { radius: Ui.radiusSmall }
                }
            }
        }
    }

    // The chosen (or pointed-at) achievement's details.
    Column {
        visible: sec.current !== null
        width: parent.width
        spacing: 2
        Text {
            width: parent.width
            text: sec.current ? sec.current.name : ""
            color: Ui.onScrim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        Text {
            visible: text !== ""
            width: parent.width
            text: sec.current ? sec.current.description : ""
            color: Ui.onScrimDim
            font.family: Ui.fontText
            font.pixelSize: Ui.textBody
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: !sec.current ? ""
                : sec.current.unlocked ? "Unlocked on " + sec.when(sec.current.time)
                : "Locked" + (sec.current.percent >= 0 ? " · " + sec.current.percent.toFixed(1) + "% of players have it" : "")
            color: sec.current && sec.current.unlocked ? Backend.theme.accent.accent : Ui.onScrimDim
            font.family: Ui.fontText
            font.weight: Font.DemiBold
            font.pixelSize: Ui.textCaption
        }
    }

    CButton {
        visible: sec.items.length > sec.columns * 2
        kind: "scrim"
        text: sec.expanded ? "Show fewer" : "Show all " + sec.items.length
        onClicked: sec.expanded = !sec.expanded
    }
}
