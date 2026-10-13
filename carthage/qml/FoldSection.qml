// A section folded to its title until opened: folded, none of its text shows (a cut-off
// preview read as broken); its title and arrow open it.
import QtQuick
import Carthage

Column {
    id: sec

    property string title
    property string text
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
        visible: sec.expanded
        width: Math.min(parent.width, 720)  // readable lines on a wide view
        text: sec.text
        color: Ui.onScrimDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textLead
        lineHeight: 1.3
        wrapMode: Text.Wrap
    }
}
