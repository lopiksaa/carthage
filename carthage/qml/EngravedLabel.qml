// A label cut into the plastic, lit from the top-left.
import QtQuick
import Carthage

Item {
    id: label

    property string text
    property int pixelSize: Ui.textLead
    property bool onMetal: false
    readonly property var pal: Backend.theme.p
    readonly property bool hifi: Backend.theme.skin === "hifi"

    implicitWidth: cut.implicitWidth
    implicitHeight: cut.implicitHeight + 1
    Accessible.role: Accessible.Heading
    Accessible.name: text

    Text {
        x: 1
        y: 1
        text: cut.text
        font: cut.font
        color: label.onMetal ? Qt.rgba(1, 1, 1, 0.7) : label.pal.engraveHi
    }
    Text {
        id: cut
        text: label.text.toUpperCase()
        color: label.onMetal ? label.pal.dockTextDim : label.pal.trayTextDim
        font.family: label.hifi ? "Barlow Condensed" : "Nunito"
        font.weight: label.hifi ? Font.Bold : Font.Black
        font.pixelSize: label.hifi ? label.pixelSize + 1 : label.pixelSize
        font.letterSpacing: label.hifi ? 3 : (label.pixelSize >= Ui.textTitle ? 3 : 2)
    }
}
