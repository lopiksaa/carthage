// Text folded to a few lines until opened.
import QtQuick
import Carthage

Column {
    id: sec

    property string title
    property string text
    property int foldedLines: 4
    property bool expanded: false

    visible: text !== ""
    spacing: Ui.gapS

    Row {
        spacing: Ui.gapS
        Accessible.role: Accessible.Button
        Accessible.name: sec.title + (sec.expanded ? ", open" : ", folded")
        Text {
            text: sec.title
            color: Ui.onScrim
            font.family: Ui.fontText
            font.weight: Font.Black
            font.pixelSize: Ui.textLead
        }
        CIcon {
            visible: body.truncated || sec.expanded
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            source: sec.expanded ? "go-up-symbolic" : "go-down-symbolic"
            isMask: true
            color: Ui.onScrimDim
        }
        TapHandler { onTapped: sec.expanded = !sec.expanded }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Text {
        id: body
        width: parent.width
        text: sec.text
        color: Ui.onScrimDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textBody
        lineHeight: 1.15
        wrapMode: Text.Wrap
        maximumLineCount: sec.expanded ? 400 : sec.foldedLines
        elide: Text.ElideRight
        TapHandler { onTapped: sec.expanded = !sec.expanded }
    }
}
