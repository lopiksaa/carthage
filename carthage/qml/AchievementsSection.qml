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
    // The icon the bubble points at (pointed or focused, else the clicked one).
    property Item pointedItem: null
    property Item chosenItem: null
    readonly property Item bubbleFor: pointedItem || chosenItem

    // "Loading…" only once it's slow: most answers come quickly, and a game without
    // achievements would otherwise show the heading for a moment and pull the page up after.
    visible: appid > 0 && ((loading && slowLoad.done) || !!result.error || items.length > 0)
    Timer {
        id: slowLoad
        property bool done: false
        interval: 600
        onTriggered: done = true
    }
    spacing: Ui.gapS

    onAppidChanged: {
        result = ({})
        expanded = false
        chosen = -1
        pointed = -1
        chosenItem = null
        pointedItem = null
        slowLoad.done = false
        if (appid > 0) {
            loading = true
            slowLoad.restart()
            Backend.achievements.load(appid)
        }
    }
    Connections {
        target: Backend.achievements
        function onReady(id, result) {
            if (id !== sec.appid) return
            sec.result = result
            sec.loading = false
            slowLoad.stop()
        }
    }

    function when(t) {
        return new Date(t * 1000).toLocaleDateString(Qt.locale("en_GB"), "d MMM yyyy")  // English, like the rest
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
                function point(on) {
                    sec.pointed = on ? index : (sec.pointed === index ? -1 : sec.pointed)
                    sec.pointedItem = on ? ach : (sec.pointedItem === ach ? null : sec.pointedItem)
                }
                onHoveredChanged: point(hovered || activeFocus)
                onActiveFocusChanged: point(hovered || activeFocus)
                onClicked: {  // pins its bubble (click again to unpin)
                    const again = sec.chosen === index
                    sec.chosen = again ? -1 : index
                    sec.chosenItem = again ? null : ach
                }
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

    // The pointed-at (or pinned) achievement's details, in a bubble above its icon: it floats
    // over the page, so nothing below moves.
    QQC2.Popup {
        id: bubble
        parent: sec.bubbleFor
        visible: sec.bubbleFor !== null && sec.current !== null
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? -height - 10 : 0
        width: Math.min(300, Math.max(200, bubbleName.implicitWidth + 2 * padding))
        margins: 8
        padding: 12
        modal: false
        dim: false
        focus: false
        closePolicy: QQC2.Popup.NoAutoClose
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Ui.motionFast * Backend.motion; easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 70 * Backend.motion; easing.type: Easing.InCubic } }
        background: Item {
            PanelBackground {
                anchors.fill: parent
                radius: Ui.radiusMedium
                shadowOffset: 4
                shadowBlur: 16
                shadowOpacity: 0.3
            }
            Rectangle {  // the bubble's point, toward the icon
                x: Math.round(parent.width / 2 - width / 2)
                y: parent.height - height / 2 - 1
                width: 12
                height: 12
                rotation: 45
                color: Backend.theme.p.panel
            }
        }
        contentItem: Column {
            spacing: 2
            Text {
                id: bubbleName
                width: bubble.availableWidth
                text: sec.current ? sec.current.name : ""
                color: Backend.theme.p.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                wrapMode: Text.Wrap
            }
            Text {
                visible: text !== ""
                width: bubble.availableWidth
                text: sec.current ? sec.current.description : ""
                color: Backend.theme.p.panelTextDim
                font.family: Ui.fontText
                font.pixelSize: Ui.textBody
                wrapMode: Text.Wrap
            }
            Text {
                width: bubble.availableWidth
                topPadding: 2
                text: !sec.current ? ""
                    : sec.current.unlocked ? "Unlocked on " + sec.when(sec.current.time)
                    : "Locked" + (sec.current.percent >= 0 ? " · " + sec.current.percent.toFixed(1) + "% of players have it" : "")
                color: sec.current && sec.current.unlocked ? Backend.theme.accent.accent : Backend.theme.p.panelTextDim
                font.family: Ui.fontText
                font.weight: Font.DemiBold
                font.pixelSize: Ui.textCaption
                wrapMode: Text.Wrap
            }
        }
    }

    CButton {
        visible: sec.items.length > sec.columns * 2
        kind: "scrim"
        text: sec.expanded ? "Show fewer" : "Show all " + sec.items.length
        onClicked: sec.expanded = !sec.expanded
    }
}
